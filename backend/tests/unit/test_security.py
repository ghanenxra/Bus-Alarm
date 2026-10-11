from app.core.security import hash_device_credential, verify_device_credential, encrypt_token, decrypt_token
from app.core.logging import redact_sensitive_string


def test_device_credential_hashing_and_verification():
    secret = "my-secure-device-client-secret-1234"
    cred_hash = hash_device_credential(secret)
    assert cred_hash != secret
    assert len(cred_hash) > 20
    assert verify_device_credential(secret, cred_hash) is True
    assert verify_device_credential("wrong-secret", cred_hash) is False


def test_token_encryption_and_decryption():
    plain_token = "ey.header.payload.signature"
    encrypted = encrypt_token(plain_token)
    assert encrypted != plain_token
    assert plain_token not in encrypted
    decrypted = decrypt_token(encrypted)
    assert decrypted == plain_token


def test_log_redaction():
    log_sample = "Request with token=secret_jwt_token_12345 and fcm_token: 'device_fcm_token_67890'"
    redacted = redact_sensitive_string(log_sample)
    assert "secret_jwt_token_12345" not in redacted
    assert "device_fcm_token_67890" not in redacted
    assert "[REDACTED]" in redacted
