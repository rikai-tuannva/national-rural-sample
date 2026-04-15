from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from starlette.requests import Request
from starlette.status import HTTP_400_BAD_REQUEST, HTTP_500_INTERNAL_SERVER_ERROR

from app.api.routes import router
from app.services.inference_service import InferenceService

inference_service = InferenceService()


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(
    title="National Rural Sample Backend",
    version="0.1.0",
    lifespan=lifespan,
)
app.include_router(router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, exc: Exception):
    if getattr(exc, "status_code", None):
        detail = getattr(exc, "detail", "Request failed")
        return JSONResponse(
            status_code=exc.status_code,
            content={"success": False, "error": detail},
        )

    return JSONResponse(
        status_code=HTTP_500_INTERNAL_SERVER_ERROR,
        content={"success": False, "error": "Internal server error"},
    )
