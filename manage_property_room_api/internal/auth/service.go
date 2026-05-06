package auth

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jose/manage_property_room_api/internal/domain"
	"github.com/jose/manage_property_room_api/internal/store"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
)

type Service struct {
	store  store.Store
	issuer *TokenIssuer
}

func NewService(s store.Store, issuer *TokenIssuer) *Service {
	return &Service{store: s, issuer: issuer}
}

type LoginResult struct {
	Token     string       `json:"token"`
	ExpiresAt time.Time    `json:"expiresAt"`
	User      *domain.User `json:"user"`
}

func (s *Service) Login(ctx context.Context, email, password string) (*LoginResult, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	u, err := s.store.Users().GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}
	if !VerifyPassword(u.PasswordHash, password) {
		return nil, ErrInvalidCredentials
	}
	tok, exp, err := s.issuer.Issue(u)
	if err != nil {
		return nil, err
	}
	return &LoginResult{Token: tok, ExpiresAt: exp, User: u}, nil
}

func (s *Service) Refresh(ctx context.Context, userID string) (*LoginResult, error) {
	u, err := s.store.Users().GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	tok, exp, err := s.issuer.Issue(u)
	if err != nil {
		return nil, err
	}
	return &LoginResult{Token: tok, ExpiresAt: exp, User: u}, nil
}

func (s *Service) ChangePassword(ctx context.Context, userID, oldPassword, newPassword string) error {
	u, err := s.store.Users().GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if !VerifyPassword(u.PasswordHash, oldPassword) {
		return ErrInvalidCredentials
	}
	hash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.store.Users().SetPasswordHash(ctx, userID, hash, false)
}

func (s *Service) ResetPassword(ctx context.Context, userID, newPassword string, mustChange bool) error {
	hash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.store.Users().SetPasswordHash(ctx, userID, hash, mustChange)
}
