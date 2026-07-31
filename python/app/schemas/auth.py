"""Mirrors the zod schemas in web/src/components/auth/RegisterForm.tsx and
LoginForm.tsx. Role is never a form field — self-signup is always `customer`,
matching the reference app's "role hidden" register page."""

from pydantic import BaseModel, EmailStr, Field, field_validator


class RegisterFormValues(BaseModel):
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    email: EmailStr
    password: str = Field(min_length=8)
    agreed_to_terms: bool

    @field_validator("agreed_to_terms")
    @classmethod
    def _must_agree(cls, value: bool) -> bool:
        if not value:
            raise ValueError("You must agree to the Terms of Service and Privacy Policy.")
        return value


class LoginFormValues(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)
