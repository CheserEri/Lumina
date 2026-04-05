pub mod models;

use crate::auth::models::{AuthResponse, Claims, LoginRequest, RegisterRequest, User};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use std::collections::HashMap;
use std::sync::RwLock;

static JWT_SECRET: &str = "lumina-secret-key-change-in-production";

pub struct AuthManager {
    users: RwLock<HashMap<String, User>>,
}

impl AuthManager {
    pub fn new() -> Self {
        Self {
            users: RwLock::new(HashMap::new()),
        }
    }

    pub fn register(&self, req: RegisterRequest) -> Result<AuthResponse, String> {
        let mut users = self.users.write().map_err(|_| "Lock error")?;

        if users.values().any(|u| u.username == req.username) {
            return Err("Username already exists".to_string());
        }
        if users.values().any(|u| u.email == req.email) {
            return Err("Email already exists".to_string());
        }

        let password_hash =
            bcrypt::hash(&req.password, bcrypt::DEFAULT_COST).map_err(|e| e.to_string())?;

        let id = uuid::Uuid::new_v4().to_string();
        let user = User {
            id: id.clone(),
            username: req.username.clone(),
            email: req.email.clone(),
            password_hash,
        };

        users.insert(id.clone(), user);

        let token = Self::generate_token(&req.username, &id)?;

        Ok(AuthResponse {
            token,
            username: req.username,
            email: req.email,
        })
    }

    pub fn login(&self, req: LoginRequest) -> Result<AuthResponse, String> {
        let users = self.users.read().map_err(|_| "Lock error")?;

        let user = users
            .values()
            .find(|u| u.username == req.username)
            .ok_or("Invalid username or password")?;

        let valid =
            bcrypt::verify(&req.password, &user.password_hash).map_err(|e| e.to_string())?;

        if !valid {
            return Err("Invalid username or password".to_string());
        }

        let token = Self::generate_token(&user.username, &user.id)?;

        Ok(AuthResponse {
            token,
            username: user.username.clone(),
            email: user.email.clone(),
        })
    }

    pub fn validate_token(&self, token: &str) -> Result<Claims, String> {
        let key = DecodingKey::from_secret(JWT_SECRET.as_bytes());
        let mut validation = Validation::default();
        validation.validate_exp = false;

        decode::<Claims>(token, &key, &validation)
            .map(|data| data.claims)
            .map_err(|e| e.to_string())
    }

    fn generate_token(username: &str, user_id: &str) -> Result<String, String> {
        let exp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_secs() as usize
            + 86400 * 7;

        let claims = Claims {
            sub: user_id.to_string(),
            username: username.to_string(),
            exp,
        };

        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(JWT_SECRET.as_bytes()),
        )
        .map_err(|e| e.to_string())
    }
}
