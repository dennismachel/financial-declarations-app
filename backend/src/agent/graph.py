"""LangGraph state graph definition for the forensic compliance agent."""

from typing import Any
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver

from backend.src.config import get_settings
from backend.src.agent.prompts import SYSTEM_PROMPT
from backend.src.agent.tools import ALL_TOOLS

settings = get_settings()


def create_compliance_agent():
    """Initializes and returns the compiled LangGraph compliance workflow."""
    llm = ChatOpenAI(
        model=settings.LLM_MODEL,
        temperature=settings.LLM_TEMPERATURE,
        api_key=settings.OPENAI_API_KEY,
    )

    # In-memory checkpointer retains session context for multi-turn investigative interviews
    checkpointer = MemorySaver()

    # Prebuilt ReAct agent handles LLM -> Tool Call -> Tool Node -> Final Answer loop
    app = create_react_agent(
        model=llm,
        tools=ALL_TOOLS,
        checkpointer=checkpointer,
        prompt=SystemMessage(content=SYSTEM_PROMPT),
    )
    return app


# Application singleton
agent_app = create_compliance_agent()


async def run_compliance_agent(
    prompt: str, thread_id: str = "default_case"
) -> dict[str, Any]:
    """Runs the compliance agent and extracts answer, SQL execution details, and citations."""
    config = {"configurable": {"thread_id": thread_id}}
    inputs = {"messages": [HumanMessage(content=prompt)]}

    # Invoke graph execution asynchronously
    result = await agent_app.ainvoke(inputs, config=config)
    messages = result.get("messages", [])

    final_answer = ""
    sql_executed = None
    citations = []

    # Parse message stream for final synthesis and tool metadata
    for msg in reversed(messages):
        if msg.type == "ai" and msg.content and not final_answer:
            final_answer = msg.content
            break

    # Extract executed SQL from tool call steps for audit logging
    for msg in messages:
        if hasattr(msg, "tool_calls") and msg.tool_calls:
            for call in msg.tool_calls:
                if call["name"] == "execute_sql_query":
                    sql_executed = call["args"].get("query")

        # Parse tool outputs for PDF citations
        if msg.type == "tool" and msg.name == "execute_sql_query":
            content = msg.content
            if isinstance(content, dict) and "rows" in content:
                for row in content["rows"]:
                    if isinstance(row, dict) and "source_pdf_filename" in row:
                        citation = {
                            "pdf": row.get("source_pdf_filename"),
                            "page": row.get("source_pdf_page", 1),
                        }
                        if citation not in citations:
                            citations.append(citation)

    return {
        "answer": final_answer,
        "sql_executed": sql_executed,
        "citations": citations,
        "anomaly_flagged": "flag_wealth_anomaly = TRUE" in (sql_executed or "")
        or "anomaly" in final_answer.lower(),
    }