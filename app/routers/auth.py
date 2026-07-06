from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import AuthOut, LoginIn, SignUpIn
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


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
            detail = "Username is already taken"
        else:
            detail = "Email is already taken"
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)

    user = User(
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        role="athlete",
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username or email is already taken",
        ) from None
    db.refresh(user)
    return AuthOut(access_token=create_access_token(user.id), user=user)


@router.post("/login", response_model=AuthOut)
def login(payload: LoginIn, db: Session = Depends(get_db)) -> AuthOut:
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    return AuthOut(access_token=create_access_token(user.id), user=user)
