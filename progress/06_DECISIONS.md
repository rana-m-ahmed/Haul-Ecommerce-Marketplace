# 06 — Decisions Log (append-only)

Never edit or delete a past entry. If a decision is reversed, add a new entry that supersedes it and say so explicitly.

---

### Decision-001 — Backend host: FastAPI on Hugging Face Spaces over Cloudflare Workers
**Date:** Sprint 0
**Context:** The project needs a free, no-credit-card backend host for AI/payment secrets and trusted writes. Cloudflare Workers never sleeps and needs no card, but trusted Firestore writes from a Worker require hand-implementing Google service-account JWT signing — a security-critical path that's easy to get subtly wrong in a vibe-coded build. FastAPI on Hugging Face Spaces needs no card either, and Python's `firebase-admin` library handles service-account auth correctly out of the box, but the free tier can sleep after inactivity.
**Decision:** Use FastAPI on Hugging Face Spaces. Mitigate the sleep risk with a GitHub Actions keep-warm ping every 10 minutes plus a client-side "waking up" loading state on the first call of a session.
**Reasoning:** Correctness of the security-critical path (order/payment trust boundary) matters more than the marginal infrastructure advantage of never sleeping, especially in an agent-written codebase where a hand-rolled JWT implementation is harder for a human to review confidently than a well-trodden library call.

---

### Decision-002 — Product images via Firebase Hosting, not Cloud Storage
**Date:** Sprint 0
**Context:** Firebase Cloud Storage now requires a billing account attached to the project even to stay within free usage. This conflicts with the project's no-credit-card constraint.
**Decision:** Serve static optimized product images (thumbnails + hero images) from Firebase Hosting instead.
**Reasoning:** Hosting needs no billing account attachment and is sufficient for a fixed 50-product demo catalog.

---

### Decision-003 — [template for your next entry]
**Date:**
**Context:**
**Decision:**
**Reasoning:**
