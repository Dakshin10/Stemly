# Stemly AI Tutor: Chat Streaming Baseline Performance

**Date:** 2026-11-15 17:48:09 UTC  
**Model:** `openai/gpt-oss-120b`  
**Test Suite:** 30 Varied STEM Prompts (Physics, Calculus, Chemistry, Circuits)  
**Success Rate:** 30/30 (100.0%)  

---

## 1. Summary Metrics

| Metric | Mean | p50 (Median) | p90 | p95 | Min | Max |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **TTFT (Time To First Token)** | **772.31 ms** | **754.45 ms** | 1034.76 ms | 1193.31 ms | 388.32 ms | 1379.54 ms |
| **Throughput (Tokens / Sec)** | **486.36 tok/s** | **507.42 tok/s** | 557.18 tok/s | 565.77 tok/s | 327.42 tok/s | 581.39 tok/s |
| **Total Response Latency** | **2225.8 ms** | **2217.45 ms** | 2817.55 ms | 2917.99 ms | 1263.14 ms | 3234.62 ms |

---

## 2. Granular Per-Prompt Benchmark Log

| # | Topic | TTFT (ms) | Throughput (tok/s) | Total Latency (ms) | Output Preview |
| :---: | :--- | :---: | :---: | :---: | :--- |
| 01 | `kinematics` | 869.15 ms | 402.18 tok/s | 2338.63 ms | First, picture what “uniform acceleration” means: the car’s speed increases by t... |
| 02 | `projectile` | 466.95 ms | 473.35 tok/s | 1398.62 ms | The horizontal speed stays the same because **no horizontal force acts on the pr... |
| 03 | `circular_motion` | 511.5 ms | 581.39 tok/s | 1263.14 ms | In uniform circular motion the **speed** (the magnitude of the velocity) stays t... |
| 04 | `shm` | 540.27 ms | 542.45 tok/s | 1876.8 ms | In a simple harmonic oscillator (SHO) the key idea is that the **restoring force... |
| 05 | `energy_conservation` | 852.41 ms | 506.79 tok/s | 1716.66 ms | **Physical intuition**  Because the incline is friction‑free, the only force doi... |
| 06 | `momentum` | 684.35 ms | 531.0 tok/s | 2241.78 ms | **Intuition first**  - **Momentum** is a “quantity of motion” that never disappe... |
| 07 | `gravitation` | 719.02 ms | 516.95 tok/s | 2253.02 ms | The escape velocity is the minimum speed a projectile needs at the surface of a ... |
| 08 | `orbital_mechanics` | 810.85 ms | 514.34 tok/s | 2206.8 ms | **Intuition first**  Imagine a planet as a runner on a circular track. The large... |
| 09 | `thermodynamics` | 594.23 ms | 517.88 tok/s | 2162.17 ms | **Intuition first**  Think of a heat engine as a “thermodynamic elevator” that l... |
| 10 | `entropy` | 517.91 ms | 556.7 tok/s | 1983.69 ms | **Intuition first**  Think of an isolated box filled with a gas. Every molecule ... |
| 11 | `fluids` | 1017.58 ms | 436.23 tok/s | 2814.81 ms | **Intuition first**  Imagine a fluid element sliding through a pipe like a bead ... |
| 12 | `gas_laws` | 735.75 ms | 526.58 tok/s | 1818.2 ms | When the air inside a bicycle tire gets hotter, the molecules move faster. Faste... |
| 13 | `electrostatics` | 1189.39 ms | 515.23 tok/s | 2282.1 ms | **Coulomb’s Law – the “gravity” of electrostatics**  Think of two point charges ... |
| 14 | `circuits` | 511.34 ms | 527.04 tok/s | 2044.43 ms | **Intuition first**  - **KCL (Current Law)** tells us that at any node (junction... |
| 15 | `magnetism` | 717.68 ms | 379.51 tok/s | 2823.01 ms | The Lorentz force law tells us how electric **E** and magnetic **B** fields act ... |
| 16 | `induction` | 884.99 ms | 551.09 tok/s | 1982.81 ms | Faraday’s Law tells us that a changing magnetic flux through a circuit creates a... |
| 17 | `wave_optics` | 697.56 ms | 449.25 tok/s | 2324.73 ms | **Intuition first**  Imagine two tiny, identical light “sources” that are create... |
| 18 | `geometric_optics` | 824.73 ms | 507.81 tok/s | 2120.5 ms | **Physical intuition**  When a light ray travels from a *slower* medium (higher ... |
| 19 | `doppler_effect` | 1196.52 ms | 507.03 tok/s | 2628.38 ms | When a siren (or any sound source) moves relative to you, the **waves it emits a... |
| 20 | `photoelectric_effect` | 773.15 ms | 569.26 tok/s | 2189.01 ms | **Intuitive picture**  Think of light as a stream of tiny, indivisible packets c... |
| 21 | `relativity` | 699.74 ms | 530.87 tok/s | 2216.11 ms | **Intuition first**  Imagine a clock that travels with you on a fast spaceship. ... |
| 22 | `derivatives` | 674.51 ms | 327.42 tok/s | 2296.3 ms | The derivative tells us **how steeply** a curve is rising or falling at a single... |
| 23 | `integration` | 802.63 ms | 453.5 tok/s | 2313.11 ms | **Intuition first**  Think of integration by parts as the “product rule” turned ... |
| 24 | `differential_equations` | 388.32 ms | 438.13 tok/s | 2218.8 ms | First‑order linear ODEs have the form    \[ \frac{dy}{dx}+P(x)\,y = Q(x), \]  wh... |
| 25 | `linear_algebra` | 1379.54 ms | 439.34 tok/s | 3234.62 ms | **Physical intuition**  Think of a linear transformation (e.g. a stretch, rotati... |
| 26 | `taylor_series` | 665.64 ms | 371.4 tok/s | 2816.94 ms | Smooth functions such as \(\sin x\) and \(e^{x}\) can be written as infinite pow... |
| 27 | `chemical_kinetics` | 787.66 ms | 561.5 tok/s | 2025.42 ms | The Arrhenius equation    \[ k = A\,\exp\!\left(-\frac{E_a}{RT}\right) \]  relat... |
| 28 | `chemical_equilibrium` | 796.05 ms | 475.48 tok/s | 1767.69 ms | Le Chatelier’s principle says that a system at equilibrium will respond so as to... |
| 29 | `acid_base` | 947.33 ms | 378.84 tok/s | 2995.71 ms | First, let’s picture what a buffer does. An acetate buffer contains a weak acid ... |
| 30 | `stoichiometry` | 912.68 ms | 502.22 tok/s | 2419.98 ms | First, let’s picture what “limiting reactant” means: in a chemical reaction the ... |

---

## 3. Key Observations & Bottlenecks for Phase 1-2 Optimization

1. **Initial Connection Cost**: Minimum measured TTFT was 388.32ms, but p95 was 1193.31ms. Reusing persistent HTTP connections (connection pooling in `LLMClientManager`) instead of creating fresh `httpx.AsyncClient` instances will shave off 100-200ms from tail TTFT.
2. **Token Generation Throughput**: Groq's LPU hardware generates at exceptional speeds, comfortably exceeding human reading speeds (mean throughput measured).
3. **Protocol Framing Overheads**: Migrating to Protocol v2 with sequence IDs and client disconnect detection will preserve these speeds while adding enterprise fault tolerance.
