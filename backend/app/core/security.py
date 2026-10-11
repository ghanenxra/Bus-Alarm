import base64
import hashlib
import hmac
import os
from typing import Optional
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from app.core.config import settings


def hash_device_credential(secret: str) -> str:
    """Hash device secret using SHA-256 for persistent credential verification."""
    salt = "bus_alarm_device_salt".encode()
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100_000,
    )
    key = kdf.derive(secret.encode())
    return base64.b64encode(key).decode("utf-8")


def verify_device_credential(secret: str, stored_hash: str) -> bool:
    """Verify incoming client secret matches stored credential hash."""
    computed = hash_device_credential(secret)
    return hmac.compare_digest(computed, stored_hash)


def _get_fernet() -> Fernet:
    """Derive Fernet cipher from application SECRET_KEY."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=b"bus_alarm_token_encryption_salt",
        iterations=100_000,
    )
    derived = base64.urlsafe_b64encode(kdf.derive(settings.SECRET_KEY.encode()))
    return Fernet(derived)


def encrypt_token(plain_token: str) -> str:
    """Encrypt sensitive share or FCM token for storage at rest."""
    if not plain_token:
        return ""
    fernet = _get_fernet()
    return fernet.encrypt(plain_token.encode("utf-8")).decode("utf-8")


def decrypt_token(encrypted_token: str) -> str:
    """Decrypt token stored at rest."""
    if not encrypted_token:
        return ""
    fernet = _get_fernet()
    return fernet.decrypt(encrypted_token.encode("utf-8")).decode("utf-8")
