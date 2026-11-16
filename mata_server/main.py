from pathlib import Path
from typing import Literal

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, field_validator

from mata_nlp.pipeline import Pipeline


load_dotenv(Path(__file__).with_name(".env"))

app = FastAPI(
    title="Ma'ta API",
    version="1.0.0",
)

pipeline = Pipeline(
    use_followup=False,
    use_layer2=False,
    use_layer3=True,
)


class ExtractionRequest(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        value = value.strip()

        if not value:
            raise ValueError("Text cannot be empty.")

        if len(value) > 2000:
            raise ValueError(
                "Text cannot exceed 2000 characters."
            )

        return value


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/extract")
def extract(request: ExtractionRequest) -> dict:
    try:
        result = pipeline.run(request.text)

        layers_run = result.get("layers_run", [])
        result["degraded"] = any(
            layer in {
                "llm:failed",
                "llm:unavailable",
            }
            for layer in layers_run
        )

        return result

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Symptom extraction failed.",
        ) from error


class SubjectRequest(BaseModel):
    result: dict
    subject: Literal["self", "other"]


@app.post("/assign-subject")
def assign_subject(request: SubjectRequest) -> dict:
    try:
        return pipeline.for_subject(request.result, request.subject)

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Updating the symptoms failed.",
        ) from error


class AgeRequest(BaseModel):
    result: dict
    age: int

    @field_validator("age")
    @classmethod
    def validate_age(cls, value: int) -> int:
        if not 0 <= value <= 120:
            raise ValueError("Age must be from 0 to 120.")

        return value


@app.post("/apply-age")
def apply_age(request: AgeRequest) -> dict:
    try:
        return pipeline.for_age(request.result, request.age)

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail="Applying the age rules failed.",
        ) from error
