"""
Unit & Integration Tests for Universal STEM Visualiser:
- Step 1: PhET Expanded Simulation Catalog (124+ sims across Physics, Chemistry, Math, Biology, Earth Science)
- Step 2: Equation & Function Detection for Dynamic Math Plotter
- Step 3: AI Micro-Simulation Sandbox (/visualiser/generate-sandbox)
- Edge Cases, Boundaries, Security & Error Handling
"""
import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services.phet_service import phet_service
from services.llm import clean_raw_equation, quick_detect_equation, detect_or_resolve_equation_plotter
from routers.visualiser_engine import _is_allowed_phet_url


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

    earth_match = phet_service.find_simulation("the greenhouse effect and global warming")
    assert earth_match is not None
    assert earth_match["slug"] == "greenhouse-effect"


def test_equation_cleaning_and_ast_formatting():
    """Step 2: Test equation syntax normalization for function_tree."""
    assert clean_raw_equation("y = x^2 - 4*x + 3") == "x^2-4*x+3"
    assert clean_raw_equation("f(x) = \\sin(x)") == "sin(x)"
    assert clean_raw_equation("y = \\frac{1}{x^2 + 1}") == "(1)/(x^2+1)"
    assert clean_raw_equation("$f(x) = \\sqrt{x}$") == "sqrt(x)"
    assert clean_raw_equation("y = 2*x + 5") == "2*x+5"
    assert clean_raw_equation("") == "x^2"
    assert clean_raw_equation(None) == "x^2"


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

    # Non-equation topic
    res5 = quick_detect_equation("projectile motion")
    assert res5 is None


def test_phet_url_security_restrictions():
    """Test strict security validation for external PhET URLs."""
    valid_url = "https://phet.colorado.edu/sims/html/projectile-motion/latest/projectile-motion_en.html"
    assert _is_allowed_phet_url(valid_url) is True

    # Insecure scheme
    assert _is_allowed_phet_url("http://phet.colorado.edu/sims/html/sim.html") is False

    # Untrusted domain / phishing attempt
    assert _is_allowed_phet_url("https://malicious-site.com/sims/html/sim.html") is False
    assert _is_allowed_phet_url("https://phet.colorado.edu.evil.com/sims/html/sim.html") is False

    # Path traversal / invalid path
    assert _is_allowed_phet_url("https://phet.colorado.edu/admin/login") is False
    assert _is_allowed_phet_url(None) is False
    assert _is_allowed_phet_url("") is False


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


@pytest.mark.asyncio
async def test_route_visualiser_generate_sandbox_fallback_modes(auth_headers):
    """Test allow_sandbox_fallback toggle for unknown topics."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Fallback to default-empty when allow_sandbox_fallback=False
        res_empty = await client.post(
            "/visualiser/generate",
            headers=auth_headers,
            json={"topic": "unsupported_unknown_topic_xyz_123", "allow_sandbox_fallback": False},
        )
        assert res_empty.status_code == 200
        assert res_empty.json()["template"]["template_id"] == "default-empty"

        # 2. Fallback to AI sandbox when allow_sandbox_fallback=True
        res_sandbox = await client.post(
            "/visualiser/generate",
            headers=auth_headers,
            json={"topic": "unsupported_unknown_topic_xyz_123", "allow_sandbox_fallback": True},
        )
        assert res_sandbox.status_code == 200
        data = res_sandbox.json()
        assert data["template"]["template_id"] == "sandbox"
        assert "<canvas" in data["template"]["metadata"]["html"]


@pytest.mark.asyncio
async def test_route_visualiser_unauthorized():
    """Verify unauthorized rejection on visualiser endpoints without token."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # /visualiser/generate without auth
        res1 = await client.post("/visualiser/generate", json={"topic": "projectile"})
        assert res1.status_code in [401, 403]

        # /visualiser/generate-sandbox without auth
        res2 = await client.post("/visualiser/generate-sandbox", json={"topic": "waves"})
        assert res2.status_code in [401, 403]

        # /visualiser/update without auth
        res3 = await client.post("/visualiser/update", json={"template_id": "projectile_motion", "parameters": {}})
        assert res3.status_code in [401, 403]


@pytest.mark.asyncio
async def test_route_visualiser_update_equation_plotter(auth_headers):
    """Test updating equation_plotter parameters with server clamping."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/visualiser/update",
            headers=auth_headers,
            json={
                "template_id": "equation_plotter",
                "parameters": {
                    "min_x": -25.0,
                    "max_x": 25.0,
                    "min_y": -15.0,
                    "max_y": 15.0,
                },
                "user_prompt": "zoom in on the vertex",
            },
        )
        assert res.status_code == 200
        data = res.json()
        assert data["template_id"] == "equation_plotter"
        assert data["parameters"]["min_x"] == -25.0
        assert data["parameters"]["max_x"] == 25.0


def test_fill_template_defaults_variable_parsing():
    """Test variable injection, equation handling, and parameter clamping in fill_template_defaults."""
    from services.visualiser_loader import fill_template_defaults

    # 1. Empty variables
    base_tpl = {"template_id": "projectile_motion", "parameters": {"U": {"value": 10.0, "min": 0.0, "max": 100.0}}}
    filled1 = fill_template_defaults(base_tpl, [])
    assert filled1["parameters"]["U"]["value"] == 10.0

    # 2. Numeric variable parsing and clamping
    filled2 = fill_template_defaults(base_tpl, ["u=45.5m/s"])
    assert filled2["parameters"]["U"]["value"] == 45.5

    # 3. Out-of-bounds variable clamping
    filled3 = fill_template_defaults(base_tpl, ["u=500.0m/s"])
    assert filled3["parameters"]["U"]["value"] == 100.0

    # 4. Equation injection into equation_plotter
    eq_tpl = {"template_id": "equation_plotter", "parameters": {}, "metadata": {"equation": "x^2"}}
    filled_eq = fill_template_defaults(eq_tpl, ["equation=sin(2*x) + 1"])
    assert filled_eq["metadata"]["equation"] == "sin(2*x)+1"

    # 5. Malformed variable formats ignored safely
    filled_malformed = fill_template_defaults(base_tpl, [123, "invalid_no_equal", "x=not_a_number"])
    assert filled_malformed["parameters"]["U"]["value"] == 10.0


@pytest.mark.asyncio
async def test_visualiser_loader_caching_and_empty():
    """Test template cache hit and empty topic handling."""
    from services.visualiser_loader import get_template_by_topic, _load_template_cached

    # Empty topic
    assert await get_template_by_topic("") is None
    assert await get_template_by_topic(None) is None

    # Load and cache
    tpl = await get_template_by_topic("projectile motion")
    assert tpl is not None
    # Cache hit
    cached_tpl = _load_template_cached("projectile_motion.json")
    assert cached_tpl is not None


@pytest.mark.asyncio
async def test_detect_or_resolve_equation_plotter_offline():
    """Test equation resolution with math keywords when LLM is offline or disabled."""
    from config import settings
    orig_key = settings.GROQ_TEXT_API_KEY
    try:
        settings.GROQ_TEXT_API_KEY = ""
        # Quadratic keyword
        res_quad = await detect_or_resolve_equation_plotter("quadratic equation problem")
        assert res_quad is not None
        assert res_quad["template_id"] == "equation_plotter"

        # Calculus keyword
        res_calc = await detect_or_resolve_equation_plotter("calculus derivative curve")
        assert res_calc is not None
        assert res_calc["template_id"] == "equation_plotter"

        # Non-math topic
        res_none = await detect_or_resolve_equation_plotter("photosynthesis in leaves")
        assert res_none is None
    finally:
        settings.GROQ_TEXT_API_KEY = orig_key
