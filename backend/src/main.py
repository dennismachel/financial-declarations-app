from contextlib import asynccontextmanager
from typing import Any, AsyncGenerator
import logging
import psycopg
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from backend.src.config import get_settings
from backend.src.agent.graph import run_compliance_agent

# Configure structured logging
settings = get_settings()
logging.basicConfig(
    level=settings.LOG_LEVEL,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("declarations_api")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Startup and shutdown lifecycle events."""
    logger.info("Starting up Financial Declarations Agent Backend...")
    logger.info(f"Target Environment: {settings.ENVIRONMENT}")
    logger.info(f"PDF Storage Directory: {settings.PDF_STORAGE_PATH}")

    # Verify database connectivity
    try:
        conninfo = str(settings.DATABASE_URL)
        async with await psycopg.AsyncConnection.connect(conninfo) as aconn:
            async with aconn.cursor() as cur:
                await cur.execute("SELECT 1;")
                result = await cur.fetchone()
                if result and result[0] == 1:
                    logger.info("PostgreSQL database connection verified successfully.")
    except Exception as exc:
        logger.error(f"FATAL: Database connection failed during startup: {exc}")
        raise exc

    yield

    logger.info("Shutting down Financial Declarations Agent Backend...")


# Initialize FastAPI Application
app = FastAPI(
    title="Employee Financial Declaration Forensic Agent",
    description="Compliance and investigative query service for personal financial disclosures.",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
)

# Cross-Origin Resource Sharing (CORS) Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# Request and Response Models
class HealthCheckResponse(BaseModel):
    status: str
    environment: str
    database: str
    pdf_storage_accessible: bool


class QueryRequest(BaseModel):
    prompt: str = Field(
        ...,
        min_length=3,
        max_length=1000,
        examples=["Find employees whose net wealth jumped faster than declared income in 2024."],
    )
    user_id: str = Field(default="investigator_default", description="Auditing actor identifier")
    investigation_case_id: str | None = Field(
        default=None,
        description="Optional case tracking identifier for audit logging",
    )


class QueryResponse(BaseModel):
    answer: str
    sql_executed: str | None = None
    citations: list[dict[str, Any]] = []
    anomaly_flagged: bool = False


# Endpoints
@app.get(
    "/health",
    response_model=HealthCheckResponse,
    tags=["System"],
    status_code=status.HTTP_200_OK,
)
async def health_check() -> HealthCheckResponse:
    """Verifies operational readiness of database, storage, and agent components."""
    db_status = "unhealthy"
    try:
        async with await psycopg.AsyncConnection.connect(str(settings.DATABASE_URL)) as aconn:
            async with aconn.cursor() as cur:
                await cur.execute("SELECT 1;")
                db_status = "healthy"
    except Exception as exc:
        logger.warning(f"Health check DB probe failed: {exc}")

    pdf_accessible = settings.PDF_STORAGE_PATH.exists() and settings.PDF_STORAGE_PATH.is_dir()

    return HealthCheckResponse(
        status="healthy" if db_status == "healthy" and pdf_accessible else "degraded",
        environment=settings.ENVIRONMENT,
        database=db_status,
        pdf_storage_accessible=pdf_accessible,
    )

@app.post("/api/v1/query", response_model=QueryResponse, tags=["Agent Query"])
async def query_declarations(payload: QueryRequest) -> QueryResponse:
    """Accepts natural language forensic questions, executes the agent, and returns citations."""
    try:
        # TODO: Hook into backend.src.agent.graph.agent_executor
        logger.info(
            f"Query received from user='{payload.user_id}', case='{payload.investigation_case_id}'"
        )

        # Placeholder response demonstrating the output structure expected by the front end
        return QueryResponse(
            answer="Inspection completed. Routing pipeline initialized.",
            sql_executed="SELECT * FROM view_employee_annual_wealth_deltas WHERE flag_wealth_anomaly = TRUE LIMIT 5;",
            citations=[
                {"pdf": "EMP-1049_2024.pdf", "page": 3, "category": "REAL_ESTATE"}
            ],
            anomaly_flagged=True,
        )
    except Exception as exc:
        logger.error(f"Error handling query: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process forensic query.",
        )