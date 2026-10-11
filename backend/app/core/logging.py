import logging
import re
import sys
from typing import Any

# Patterns to redact from logs
TOKEN_PATTERNS = [
    (re.compile(r'(token=)[^&\s"\']+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(fcm_token["\']?\s*:\s*["\'])[^"\']+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(provider_token["\']?\s*:\s*["\'])[^"\']+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(credential_hash["\']?\s*:\s*["\'])[^"\']+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(authorization["\']?\s*:\s*["\'])[^"\']+', re.IGNORECASE), r'\1[REDACTED]'),
    (re.compile(r'(bearer\s+)[a-zA-Z0-9_\-\.]+', re.IGNORECASE), r'\1[REDACTED]'),
]


def redact_sensitive_string(text: str) -> str:
    """Sanitize strings containing tokens, keys or URLs."""
    if not isinstance(text, str):
        return text
    for pattern, replacement in TOKEN_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


class RedactingFormatter(logging.Formatter):
    """Logging formatter that automatically redacts sensitive tokens and secrets."""
    def format(self, record: logging.LogRecord) -> str:
        original = super().format(record)
        return redact_sensitive_string(original)


def setup_logging(level: int = logging.INFO) -> logging.Logger:
    """Configure root and application logger with redaction."""
    logger = logging.getLogger("bus_alarm")
    logger.setLevel(level)
    
    # Avoid duplicate handlers on reloads
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = RedactingFormatter(
            fmt="%(asctime)s [%(levelname)s] [%(name)s] [%(filename)s:%(lineno)d] %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%SZ"
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.propagate = False
        
    return logger


logger = setup_logging()
