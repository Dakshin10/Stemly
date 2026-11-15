"""
Tests for Phase 2: Native Tool Calling in Chat Streaming.
Covers:
- Tool call delta reconstruction across split-JSON chunks
- Pydantic validation (UpdateSimulationArgs, SuggestFollowupsArgs)
- Server-side parameter clamping on unphysical values
- Graceful recovery on malformed tool arguments
- Backward compatibility with legacy text tags
"""

from unittest.mock import MagicMock, patch
import pytest

from models.tools import SuggestFollowupsArgs, TUTOR_TOOLS, UpdateSimulationArgs
from services.llm.text import stream_tutor_chat


class MockStreamResponse:
    def __init__(self, lines, status_code=200):
        self.lines = lines
        self.status_code = status_code

    async def aiter_lines(self):
        for line in self.lines:
            yield line

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass


def test_tutor_tools_schema_definition():
    """Verify tool definitions are valid OpenAI/Groq function calling specifications."""
    assert len(TUTOR_TOOLS) == 2
    tool_names = [t["function"]["name"] for t in TUTOR_TOOLS]
    assert "update_simulation" in tool_names
    assert "suggest_followups" in tool_names


def test_tool_args_pydantic_validation():
    """Verify UpdateSimulationArgs and SuggestFollowupsArgs validation and clamping."""
    # Test valid simulation args
    sim = UpdateSimulationArgs.model_validate({
        "parameters": {"speed": 25.0, "angle": 45.0},
        "explanation": "Increasing launch velocity",
        "visual_cue": "Watch trajectory peak",
    })
    assert sim.parameters["speed"] == 25.0

    # Test followups clamp to 3
    fu = SuggestFollowupsArgs.model_validate({
        "questions": ["Q1?", "Q2?", "Q3?", "Q4?", "Q5?"],
    })
    assert len(fu.questions) == 3
    assert fu.questions == ["Q1?", "Q2?", "Q3?"]


@pytest.mark.asyncio
async def test_tool_call_delta_reconstruction_across_split_json():
    """Verify tool call arguments split across multiple streaming chunks are reconstructed."""
    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Let us adjust the simulation."}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "call_1", "type": "function", "function": {"name": "update_simulation", "arguments": "{\\"param"}}]}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "function": {"arguments": "eters\\": {\\"speed\\": 35.0, \\"angle\\": 60.0}, \\"exp"}}]}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "function": {"arguments": "lanation\\": \\"Higher angle reaches higher apex\\", \\"visual_cue\\": \\"observe apex\\"}"}}]}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 1, "id": "call_2", "type": "function", "function": {"name": "suggest_followups", "arguments": "{\\"questions\\": [\\"Why does range change?\\", \\"What is time of flight?\\", \\"How does gravity affect it?\\", \\"Extra 4th question\\"]}"}}]}}]}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        events = []
        async for env in stream_tutor_chat(
            message="Change angle to 60 and speed to 35",
            topic="Projectile Motion",
        ):
            events.append(env)

        event_types = [e.type for e in events]
        assert "parameters" in event_types
        assert "followups" in event_types

        # Check parameter updates reconstructed and validated
        param_event = next(e for e in events if e.type == "parameters")
        updates = param_event.data["updates"]
        assert updates["speed"] == 35.0
        assert updates["angle"] == 60.0
        assert param_event.data["explanation"] == "Higher angle reaches higher apex"
        assert param_event.data["visual_cue"] == "observe apex"

        # Check followups clamped to 3
        followup_event = next(e for e in events if e.type == "followups")
        suggestions = followup_event.data["suggestions"]
        assert len(suggestions) == 3
        assert "Why does range change?" in suggestions[0]


@pytest.mark.asyncio
async def test_tool_call_parameter_clamping_on_unphysical_values():
    """Verify unphysical values generated in tool calls are clamped by parameter_sanitizer."""
    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Testing extreme bounds."}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "call_99", "type": "function", "function": {"name": "update_simulation", "arguments": "{\\"parameters\\": {\\"speed\\": 999999.0, \\"angle\\": 1500.0, \\"mass\\": -50.0}}"}}]}}]}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        events = []
        async for env in stream_tutor_chat(
            message="Set speed to maximum possible and negative mass",
            topic="Kinematics",
        ):
            events.append(env)

        param_event = next(e for e in events if e.type == "parameters")
        updates = param_event.data["updates"]
        # speed upper bound is 500.0
        assert updates["speed"] == 500.0
        # angle upper bound is 360.0
        assert updates["angle"] == 360.0
        # mass lower bound is 0.001 (never negative)
        assert updates["mass"] == 0.001


@pytest.mark.asyncio
async def test_tool_call_malformed_json_fallback():
    """Verify malformed tool call JSON triggers graceful fallback without raising exceptions."""
    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Here is an explanation."}}]}',
        'data: {"choices": [{"delta": {"tool_calls": [{"index": 0, "id": "call_bad", "type": "function", "function": {"name": "update_simulation", "arguments": "{\\"parameters\\": {\\"speed\\": 45.0, syntax_error"}}]}}]}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        events = []
        async for env in stream_tutor_chat(
            message="Test malformed tool call",
            topic="Mechanics",
        ):
            events.append(env)

        event_types = [e.type for e in events]
        assert "token" in event_types
        assert "done" in event_types
        assert events[-1].data["finish_reason"] == "stop"


@pytest.mark.asyncio
async def test_legacy_text_tag_compatibility():
    """Verify backward compatibility when model emits text control tags."""
    mock_lines = [
        'data: {"choices": [{"delta": {"content": "Trajectory updated! <<<PARAMS:{\\"speed\\": 22.0}>>> <<<FOLLOWUPS:[\\"Next step?\\", \\"Formula?\\", \\"Practice?\\"]>>>"}}]}',
        "data: [DONE]",
    ]

    with patch("services.llm.client.LLMClientManager.text_client") as mock_client:
        mock_instance = MagicMock()
        mock_instance.stream.return_value = MockStreamResponse(mock_lines, status_code=200)
        mock_client.__get__ = lambda *args, **kwargs: mock_instance

        events = []
        async for env in stream_tutor_chat(
            message="Explain trajectory",
            topic="Kinematics",
        ):
            events.append(env)

        param_event = next((e for e in events if e.type == "parameters"), None)
        assert param_event is not None
        assert param_event.data["updates"]["speed"] == 22.0

        followup_event = next((e for e in events if e.type == "followups"), None)
        assert followup_event is not None
        assert len(followup_event.data["suggestions"]) == 3
