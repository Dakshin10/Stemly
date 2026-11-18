"""
Integration test running the LangSmith Benchmark Suite in CI / local test pipeline.
"""

import pytest
from evals.run_langgraph_eval import load_dataset, run_single_example


@pytest.mark.asyncio
async def test_langsmith_eval_benchmark_suite():
    """Runs the 9-point LangSmith evaluation benchmark and asserts 100% pass rate."""
    dataset = load_dataset()
    assert len(dataset) >= 8

    failed_cases = []
    for example in dataset:
        result = await run_single_example(example)
        if not result["overall_pass"]:
            failed_cases.append(result)

    assert len(failed_cases) == 0, f"LangSmith evaluations failed on {len(failed_cases)} test cases: {failed_cases}"
