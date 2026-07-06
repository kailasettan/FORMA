import json
import logging
import random
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User, EmailOTP
from app.schemas import AuthOut, ForgotPasswordIn, LoginIn, ResetPasswordIn, SignUpIn, VerifyOTPIn, ResendOTPIn
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)
EMAIL_VERIFICATION_PURPOSE = "email_verification"
PASSWORD_RESET_PURPOSE = "password_reset"
RESET_CODE_SENT_MESSAGE = "If an account exists, a reset code has been sent."


def resend_key_hint() -> str:
    api_key = settings.resend_api_key or ""
    if not api_key:
        return "missing"
    return f"{api_key[:3]}..."


def log_resend_config_state() -> None:
    logger.info(
        "Resend config loaded: key_present=%s key_prefix=%s from_email=%s from_name=%s app_env=%s",
        bool(settings.resend_api_key),
        resend_key_hint(),
        settings.from_email,
        settings.from_name,
        settings.app_env,
    )


def _log_dev_otp_fallback(email: str, otp: str, purpose: str) -> None:
    if settings.is_development:
        logger.warning(
            "Development OTP fallback for %s purpose=%s code=%s",
            email,
            purpose,
            otp,
        )


def send_otp_email(
    email: str,
    otp: str,
    *,
    purpose: str = EMAIL_VERIFICATION_PURPOSE,
    subject: str = "Your FORMA Verification Code",
) -> None:
    api_key = settings.resend_api_key
    from_email = settings.from_email
    from_name = settings.from_name

    url = "https://api.resend.com/emails"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "from": f"{from_name} <{from_email}>",
        "to": [email],
        "subject": subject,
        "html": f"<p>Your verification code is <strong>{otp}</strong>. It will expire in 10 minutes.</p>",
        "text": f"Your FORMA verification code is {otp}. It will expire in 10 minutes.",
    }

    logger.info("OTP email send requested for %s", email)
    logger.info(
        "OTP email metadata purpose=%s from_email=%s resend_key_present=%s resend_key_prefix=%s",
        purpose,
        from_email,
        bool(api_key),
        resend_key_hint(),
    )

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        if not api_key or api_key.startswith("change-me") or "placeholder" in api_key.lower():
            logger.error("Resend send skipped: API key is missing or placeholder.")
            _log_dev_otp_fallback(email, otp, purpose)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send verification email. Please try again later.",
            )

        with urllib.request.urlopen(req, timeout=5) as response:
            logger.info("Resend HTTP status code: %s", response.status)
            if response.status not in (200, 201):
                response_body = response.read().decode("utf-8", errors="replace")
                logger.error(
                    "Resend send failed for %s purpose=%s status=%s body=%s",
                    email,
                    purpose,
                    response.status,
                    response_body,
                )
                _log_dev_otp_fallback(email, otp, purpose)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to send verification email. Please try again later.",
                )
    except HTTPException:
        raise
    except urllib.error.HTTPError as exc:
        response_body = exc.read().decode("utf-8", errors="replace")
        logger.error(
            "Resend send failed for %s purpose=%s status=%s body=%s",
            email,
            purpose,
            exc.code,
            response_body,
        )
        _log_dev_otp_fallback(email, otp, purpose)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email. Please try again later.",
        ) from None
    except urllib.error.URLError as exc:
        logger.error(
            "Resend send failed for %s purpose=%s reason=%s",
            email,
            purpose,
            exc.reason,
        )
        _log_dev_otp_fallback(email, otp, purpose)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email. Please try again later.",
        ) from None
    except Exception:
        logger.exception("Failed to send OTP email to %s purpose=%s", email, purpose)
        _log_dev_otp_fallback(email, otp, purpose)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email. Please try again later."
        ) from None


def generate_and_save_otp(db: Session, user: User, purpose: str = EMAIL_VERIFICATION_PURPOSE) -> str:
    otp = f"{random.randint(100000, 999999)}"
    otp_hash = hash_password(otp)
    now = datetime.utcnow()

    existing = db.scalar(
        select(EmailOTP).where(EmailOTP.user_id == user.id, EmailOTP.purpose == purpose)
    )
    if existing:
        existing.otp_hash = otp_hash
        existing.attempts = 0
        existing.expires_at = now + timedelta(minutes=10)
        existing.last_sent_at = now
    else:
        new_otp = EmailOTP(
            user_id=user.id,
            purpose=purpose,
            otp_hash=otp_hash,
            attempts=0,
            expires_at=now + timedelta(minutes=10),
            last_sent_at=now
        )
        db.add(new_otp)

    db.commit()
    return otp


@router.post("/signup", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
def signup(payload: SignUpIn, db: Session = Depends(get_db)) -> AuthOut:
    requested_role = payload.role.lower().strip()
    if requested_role == "scout":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Scout accounts cannot be created from public signup.",
        )
    if requested_role != "athlete":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Public signup role must be athlete.",
        )

    existing = db.scalar(
        select(User).where((User.username == payload.username) | (User.email == payload.email))
    )
    if existing is not None:
        if existing.username.lower() == payload.username.lower():
            detail = "Username is already taken."
        else:
            detail = "Email is already registered."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)

    user = User(
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        role="athlete",
        email_verified=False,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username or email is already taken.",
        ) from None
    db.refresh(user)

    # Generate and send OTP
    otp = generate_and_save_otp(db, user, EMAIL_VERIFICATION_PURPOSE)
    send_otp_email(user.email, otp, purpose=EMAIL_VERIFICATION_PURPOSE)

    return AuthOut(access_token=create_access_token(user.id), user=user)


@router.post("/login", response_model=AuthOut)
def login(payload: LoginIn, db: Session = Depends(get_db)) -> AuthOut:
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    if not user.email_verified:
        existing = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == EMAIL_VERIFICATION_PURPOSE,
            )
        )
        now = datetime.utcnow()
        should_send = True
        if existing:
            last_sent = existing.last_sent_at
            if (now - last_sent).total_seconds() < 60:
                should_send = False

        if should_send:
            otp = generate_and_save_otp(db, user, EMAIL_VERIFICATION_PURPOSE)
            try:
                send_otp_email(user.email, otp, purpose=EMAIL_VERIFICATION_PURPOSE)
            except Exception:
                pass

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified.",
        )

    return AuthOut(access_token=create_access_token(user.id), user=user)


@router.post("/verify-otp")
def verify_otp(payload: VerifyOTPIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    if user.email_verified:
        return {"message": "Email is already verified."}

    otp_entry = db.scalar(
        select(EmailOTP).where(
            EmailOTP.user_id == user.id,
            EmailOTP.purpose == EMAIL_VERIFICATION_PURPOSE,
        )
    )
    if otp_entry is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No verification code found. Please request a new one.",
        )

    if otp_entry.attempts >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many failed attempts. Please request a new code.",
        )

    expires_at = otp_entry.expires_at
    now = datetime.utcnow()
    if now > expires_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification code has expired.",
        )

    if not verify_password(payload.otp, otp_entry.otp_hash):
        otp_entry.attempts += 1
        db.commit()
        if otp_entry.attempts >= 5:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many failed attempts. Please request a new code.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code.",
        )

    user.email_verified = True
    db.delete(otp_entry)
    db.commit()
    return {"message": "Email verified successfully."}


@router.post("/resend-otp")
def resend_otp(payload: ResendOTPIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    if user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already verified.",
        )

    existing = db.scalar(
        select(EmailOTP).where(
            EmailOTP.user_id == user.id,
            EmailOTP.purpose == EMAIL_VERIFICATION_PURPOSE,
        )
    )
    now = datetime.utcnow()
    if existing:
        last_sent = existing.last_sent_at
        cooldown_remains = 60 - (now - last_sent).total_seconds()
        if cooldown_remains > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please wait 60 seconds before requesting another code.",
            )

    otp = generate_and_save_otp(db, user, EMAIL_VERIFICATION_PURPOSE)
    send_otp_email(user.email, otp, purpose=EMAIL_VERIFICATION_PURPOSE)

    return {"message": "Verification code resent."}


@router.post("/forgot-password")
def forgot_password(payload: ForgotPasswordIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is not None:
        otp = generate_and_save_otp(db, user, PASSWORD_RESET_PURPOSE)
        try:
            send_otp_email(
                user.email,
                otp,
                purpose=PASSWORD_RESET_PURPOSE,
                subject="Your FORMA Password Reset Code",
            )
        except HTTPException:
            pass

    return {"message": RESET_CODE_SENT_MESSAGE}


@router.post("/resend-password-reset-otp")
def resend_password_reset_otp(payload: ForgotPasswordIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        return {"message": RESET_CODE_SENT_MESSAGE}

    existing = db.scalar(
        select(EmailOTP).where(
            EmailOTP.user_id == user.id,
            EmailOTP.purpose == PASSWORD_RESET_PURPOSE,
        )
    )
    now = datetime.utcnow()
    if existing:
        cooldown_remains = 60 - (now - existing.last_sent_at).total_seconds()
        if cooldown_remains > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please wait 60 seconds before requesting another code.",
            )

    otp = generate_and_save_otp(db, user, PASSWORD_RESET_PURPOSE)
    try:
        send_otp_email(
            user.email,
            otp,
            purpose=PASSWORD_RESET_PURPOSE,
            subject="Your FORMA Password Reset Code",
        )
    except HTTPException:
        pass
    return {"message": RESET_CODE_SENT_MESSAGE}


@router.post("/reset-password")
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)):
    invalid_detail = "Invalid or expired reset code."
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail)

    otp_entry = db.scalar(
        select(EmailOTP).where(
            EmailOTP.user_id == user.id,
            EmailOTP.purpose == PASSWORD_RESET_PURPOSE,
        )
    )
    if otp_entry is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail)

    if otp_entry.attempts >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many failed attempts. Please request a new code.",
        )

    if datetime.utcnow() > otp_entry.expires_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail)

    if not verify_password(payload.otp, otp_entry.otp_hash):
        otp_entry.attempts += 1
        db.commit()
        if otp_entry.attempts >= 5:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many failed attempts. Please request a new code.",
            )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=invalid_detail)

    user.password_hash = hash_password(payload.new_password)
    db.delete(otp_entry)
    db.commit()
    return {"message": "Password reset successfully."}
