from typing import List, Optional

from pydantic import BaseModel, Field


class QuizTopic(BaseModel):
    id: int = Field(..., ge=1)
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=300)


class QuizQuestion(BaseModel):
    id: int = Field(..., ge=1)
    topic_id: int = Field(..., ge=1)
    question: str = Field(..., min_length=1, max_length=500)
    options: List[str] = Field(..., min_length=2, max_length=10)
    correct_index: int = Field(..., ge=0, le=9)  # position of correct answer


class QuizAnswerRequest(BaseModel):
    question_id: int = Field(..., ge=1)
    selected_index: int = Field(..., ge=0, le=9)


class QuizSubmission(BaseModel):
    answers: List[QuizAnswerRequest] = Field(..., min_length=1, max_length=100)


class QuizResult(BaseModel):
    score: int = Field(..., ge=0)
    total: int = Field(..., ge=0)
    correct_questions: List[int] = Field(default_factory=list)
