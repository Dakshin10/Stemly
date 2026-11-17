"""
Unit & Integration Tests for Universal STEM Visualiser:
- Step 1: PhET Expanded Simulation Catalog (124+ sims across Physics, Chemistry, Math, Biology, Earth Science)
- Step 2: Equation & Function Detection for Dynamic Math Plotter
- Step 3: AI Micro-Simulation Sandbox (/visualiser/generate-sandbox)
"""
import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services.phet_service import phet_service
from services.llm import clean_raw_equation, quick_detect_equation, detect_or_resolve_equation_plotter


def test_phet_expanded_catalog_coverage():
    """Step 1: Test that PhET catalog covers across all core STEM subjects."""
    assert len(phet_service.simulations) >= 120, "PhET catalog must contain 120+ simulations"

    subjects = {sim.get("subject") for sim in phet_service.simulations}
    assert "physics" in subjects
    assert "chemistry" in subjects
    assert "math" in subjects
    assert "biology" in subjects
    assert "earth-science" in subjects

    # Test key domain lookups
    chem_match = phet_service.find_simulation("balancing chemical equations")
    assert chem_match is not None
    assert chem_match["slug"] == "balancing-chemical-equations"
    assert "phet.colorado.edu" in chem_match["url"]

    bio_match = phet_service.find_simulation("gene expression and transcription")
    assert bio_match is not None
    assert bio_match["slug"] == "gene-expression-essentials"

    neuro_match = phet_service.find_simulation("action potential in neuron")
    assert neuro_match is not None
    assert neuro_match["slug"] == "neuron"

    math_match = phet_service.find_simulation("calculus derivative and tangent")
    assert math_match is not None
    assert math_match["slug"] == "calculus-grapher"


def test_equation_cleaning_and_ast_formatting():
    """Step 2: Test equation syntax normalization for function_tree."""
    assert clean_raw_equation("y = x^2 - 4*x + 3") == "x^2-4*x+3"
    assert clean_raw_equation("f(x) = \\sin(x)") == "sin(x)"
    assert clean_raw_equation("y = \\frac{1}{x^2 + 1}") == "(1)/(x^2+1)"
    assert clean_raw_equation("$f(x) = \\sqrt{x}$") == "sqrt(x)"
    assert clean_raw_equation("y = 2*x + 5") == "2*x+5"


def test_quick_detect_equation_heuristics():
    """Step 2: Test fast zero-latency regex detection of equations."""
    res1 = quick_detect_equation("y = x^2 - 9")
    assert res1 is not None
    assert res1["template_id"] == "equation_plotter"
    assert res1["metadata"]["equation"] == "x^2-9"

    res2 = quick_detect_equation("f(x) = sin(x) + cos(x)")
    assert res2 is not None
    assert res2["template_id"] == "equation_plotter"
    assert res2["metadata"]["equation"] == "sin(x)+cos(x)"

    res3 = quick_detect_equation("plot y = 3*x - 2")
    assert res3 is not None
    assert res3["template_id"] == "equation_plotter"
    assert res3["metadata"]["equation"] == "3*x-2"

    res4 = quick_detect_equation("algebraic variables", ["equation=x^3 - 3*x"])
    assert res4 is not None
    assert res4["template_id"] == "equation_plotter"
    assert res4["metadata"]["equation"] == "x^3-3*x"


@pytest.mark.asyncio
async def test_route_visualiser_generate_with_equation(auth_headers):
    """Step 2: POST /visualiser/generate returns equation_plotter with raw formula."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/visualiser/generate",
            headers=auth_headers,
            json={"topic": "y = x^2 - 4x + 4"},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        template = data["template"]
        assert template["template_id"] == "equation_plotter"
        assert "equation" in template["metadata"]
        assert template["metadata"]["equation"] == "x^2-4x+4"


@pytest.mark.asyncio
async def test_route_visualiser_generate_sandbox_endpoint(auth_headers):
    """Step 3: POST /visualiser/generate-sandbox generates HTML5 canvas micro-simulation."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/visualiser/generate-sandbox",
            headers=auth_headers,
            json={
                "topic": "Capacitor Charging and Discharging RC Circuit",
                "prompt": "Show capacitor voltage over time with exponential decay",
                "variables": ["R=1000ohm", "C=10uF"],
            },
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["template_id"] == "sandbox"
        assert "<canvas" in data["html"]
        assert "</script>" in data["html"]
        assert "template" in data
        assert data["template"]["metadata"]["type"] == "sandbox"
