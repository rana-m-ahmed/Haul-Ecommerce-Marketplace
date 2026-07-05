"""Compatibility shim for the former misspelled provider module."""

from backend.app.core.groq_client import GroqClient


class GrokClient(GroqClient):
    pass
