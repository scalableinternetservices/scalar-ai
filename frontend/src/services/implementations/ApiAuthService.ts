import type {
  AuthService,
  RegisterRequest,
  User,
  AuthServiceConfig,
} from '@/types';
import TokenManager from '@/services/TokenManager';

/**
 * API-based implementation of AuthService
 * Uses fetch for HTTP requests
 */
export class ApiAuthService implements AuthService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: AuthServiceConfig) {
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.tokenManager = TokenManager.getInstance();
  }

  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // TODO: Implement the makeRequest helper method
    // This should:
    // 1. Construct the full URL using this.baseUrl and endpoint
    // 2. Set up default headers including 'Content-Type': 'application/json'
    // 3. Use {credentials: 'include'} for session cookies
    // 4. Make the fetch request with the provided options
    // 5. Handle non-ok responses by throwing an error with status and message
    // 6. Return the parsed JSON response
    const fullUrl: string = `${this.baseUrl}${endpoint}`;
    const response: Response = await fetch(fullUrl, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
      credentials: 'include',
    });
    if (!response.ok) {
      const errorText: string = await response.text();
      throw new Error(`Auth request error ${response.status}: ${errorText}`);
    }
    return response.json() as Promise<T>;
  }

  async login(username: string, password: string): Promise<User> {
    // TODO: Implement login method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details
    const LOGIN_ENDPOINT: string = "/auth/login";
    const response = await this.makeRequest<{token: string; user: User}>(LOGIN_ENDPOINT, {
      method: "POST",
      body: JSON.stringify({username, password}),
    });
    this.tokenManager.setToken(response.token);
    return response.user;
  }

  async register(userData: RegisterRequest): Promise<User> {
    // TODO: Implement register method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details
    
    // Validate password length
    if (userData.password.length < 6) {
      throw new Error('Password must be at least 6 characters');
    }
    
    const REGISTER_ENDPOINT: string = "/auth/register";
    const response = await this.makeRequest<{token: string; user: User}>(REGISTER_ENDPOINT, {
      method: "POST",
      body: JSON.stringify(userData),
    });
    this.tokenManager.setToken(response.token);
    return response.user;
  }

  async logout(): Promise<void> {
    // TODO: Implement logout method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Handle errors gracefully (continue with logout even if API call fails)
    // 3. Clear the token using this.tokenManager.clearToken()
    //
    // See API_SPECIFICATION.md for endpoint details
    const LOGOUT_ENDPOINT: string = "/auth/logout";
    try {
      await this.makeRequest<void>(LOGOUT_ENDPOINT, {
        method: "POST",
      });
    } catch (error) {
      console.error("Logout request failed:", error);
    } finally {
      this.tokenManager.clearToken();
    }
  }

  async refreshToken(): Promise<User> {
    // TODO: Implement refreshToken method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 3. Update the stored token using this.tokenManager.setToken(response.token)
    // 4. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details
    const REFRESH_TOKEN_ENDPOINT: string = "/auth/refresh";
    const response = await this.makeRequest<{token: string; user: User}>(REFRESH_TOKEN_ENDPOINT, {
      method: "POST",
    });
    this.tokenManager.setToken(response.token);
    return response.user;
  }

  async getCurrentUser(): Promise<User | null> {
    // TODO: Implement getCurrentUser method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the user object if successful
    // 3. If the request fails (e.g., session invalid), clear the token and return null
    //
    // See API_SPECIFICATION.md for endpoint details
    const CURRENT_USER_ENDPOINT: string = "/auth/me";
    try {
      const response = await this.makeRequest<{ user: User }>(CURRENT_USER_ENDPOINT, {
        method: "GET",
      });
      return response.user;
    } catch (error) {
      console.error("Get current user request failed:", error);
      this.tokenManager.clearToken();
      return null;
    }
  }
}
