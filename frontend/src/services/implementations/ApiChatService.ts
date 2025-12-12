import type { ChatService } from '@/types';
import type {
  Conversation,
  CreateConversationRequest,
  UpdateConversationRequest,
  Message,
  SendMessageRequest,
  ExpertProfile,
  ExpertQueue,
  ExpertAssignment,
  UpdateExpertProfileRequest,
} from '@/types';
import TokenManager from '@/services/TokenManager';

interface ApiChatServiceConfig {
  baseUrl: string;
  timeout: number;
  retryAttempts: number;
}

/**
 * API implementation of ChatService for production use
 * Uses fetch for HTTP requests
 */
export class ApiChatService implements ChatService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: ApiChatServiceConfig) {
    this.baseUrl = config.baseUrl;
    this.tokenManager = TokenManager.getInstance();
  }

  private async makeRequest<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // TODO: Implement the makeRequest helper method
    // This should:
    // 1. Construct the full URL using this.baseUrl and endpoint
    // 2. Get the token using this.tokenManager.getToken()
    // 3. Set up default headers including 'Content-Type': 'application/json'
    // 4. Add Authorization header with Bearer token if token exists
    // 5. Make the fetch request with the provided options
    // 6. Handle non-ok responses by throwing an error with status and message
    // 7. Return the parsed JSON response
    const fullUrl: string = `${this.baseUrl}${endpoint}`;
    const token: string | null = this.tokenManager.getToken();
    const response: Response = await fetch(fullUrl, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.headers || {}),
      },
      // credentials: 'include',
    });
    if (!response.ok) {
      const errorText: string = await response.text();
      throw new Error(`Chat request error ${response.status}: ${errorText}`);
    }
    return response.json() as Promise<T>;
  }

  // Conversations
  async getConversations(): Promise<Conversation[]> {
    // TODO: Implement getConversations method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of conversations
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_CONVERSATIONS_ENDPOINT: string = "/conversations";
    const response = await this.makeRequest<Conversation[]>(GET_CONVERSATIONS_ENDPOINT, {
      method: "GET",
    });
    return response;
  }

  async getConversation(_id: string): Promise<Conversation> {
    // TODO: Implement getConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the conversation object
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_ONE_CONV_ENDPOINT: string = `/conversations/${_id}`;
    const response = await this.makeRequest<Conversation>(GET_ONE_CONV_ENDPOINT, {
      method: "GET",
    });
    return response;
  }

  async createConversation(
    request: CreateConversationRequest
  ): Promise<Conversation> {
    // TODO: Implement createConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created conversation object
    //
    // See API_SPECIFICATION.md for endpoint details
    const CREATE_CONV_ENDPOINT: string = "/conversations";
    const response = await this.makeRequest<Conversation>(CREATE_CONV_ENDPOINT, {
      method: "POST",
      body: JSON.stringify(request),
    });
    return response;
  }

  async updateConversation(
    id: string,
    request: UpdateConversationRequest
  ): Promise<Conversation> {
    // Implement updateConversation to resolve conversations
    // Only supports status: 'resolved' for now
    if (request.status === 'resolved') {
      const RESOLVE_CONV_ENDPOINT: string = `/expert/conversations/${id}/resolve`;
      const response = await this.makeRequest<Conversation>(RESOLVE_CONV_ENDPOINT, {
        method: "POST",
      });
      return response;
    }
    
    throw new Error('updateConversation only supports resolving conversations');
  }

  async deleteConversation(id: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('deleteConversation method not implemented');
  }

  // Messages
  async getMessages(conversationId: string): Promise<Message[]> {
    // TODO: Implement getMessages method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of messages
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_MESSAGES_ENDPOINT: string = `/conversations/${conversationId}/messages`;
    const response = await this.makeRequest<Message[]>(GET_MESSAGES_ENDPOINT, {
      method: "GET",
    });
    return response;
  }

  async sendMessage(request: SendMessageRequest): Promise<Message> {
    // TODO: Implement sendMessage method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the created message object
    //
    // See API_SPECIFICATION.md for endpoint details
    const SEND_MESSAGE_ENDPOINT: string = `/messages`;
    const response = await this.makeRequest<Message>(SEND_MESSAGE_ENDPOINT, {
      method: "POST",
      body: JSON.stringify(request),
    });
    return response;
  }

  async markMessageAsRead(messageId: string): Promise<void> {
    // SKIP, not currently used by application

    throw new Error('markMessageAsRead method not implemented');
  }

  // Expert-specific operations
  async getExpertQueue(): Promise<ExpertQueue> {
    // TODO: Implement getExpertQueue method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert queue object with waitingConversations and assignedConversations
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_EXPERT_QUEUE_ENDPOINT: string = "/expert/queue";
    const response = await this.makeRequest<ExpertQueue>(GET_EXPERT_QUEUE_ENDPOINT, {
      method: "GET",
    });
    return response;
  }

  async claimConversation(conversationId: string): Promise<void> {
    // TODO: Implement claimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details
    const CLAIM_CONV_ENDPOINT: string = `/expert/conversations/${conversationId}/claim`;
    await this.makeRequest<void>(CLAIM_CONV_ENDPOINT, {
      method: "POST",
    });
  }

  async unclaimConversation(conversationId: string): Promise<void> {
    // TODO: Implement unclaimConversation method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return void (no response body expected)
    //
    // See API_SPECIFICATION.md for endpoint details
    const UNCLAIM_CONV_ENDPOINT: string = `/expert/conversations/${conversationId}/unclaim`;
    await this.makeRequest<void>(UNCLAIM_CONV_ENDPOINT, {
      method: "POST",
    });
  }

  async getExpertProfile(): Promise<ExpertProfile> {
    // TODO: Implement getExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_EXPERT_PROFILE_ENDPOINT: string = "/expert/profile";
    const response = await this.makeRequest<ExpertProfile>(GET_EXPERT_PROFILE_ENDPOINT, {
      method: "GET",
    });
    return response;
    // FIXME: might have extra members not in the type
  }

  async updateExpertProfile(
    request: UpdateExpertProfileRequest
  ): Promise<ExpertProfile> {
    // TODO: Implement updateExpertProfile method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the updated expert profile object
    //
    // See API_SPECIFICATION.md for endpoint details
    const UPDATE_EXPERT_PROFILE_ENDPOINT: string = "/expert/profile";
    const response = await this.makeRequest<ExpertProfile>(UPDATE_EXPERT_PROFILE_ENDPOINT, {
      method: "PUT",
      body: JSON.stringify(request),
    });
    return response;
  }

  async getExpertAssignmentHistory(): Promise<ExpertAssignment[]> {
    // TODO: Implement getExpertAssignmentHistory method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the array of expert assignments
    //
    // See API_SPECIFICATION.md for endpoint details
    const GET_EXPERT_ASSIGNMENT_HISTORY_ENDPOINT: string = "/expert/assignments/history";
    const response = await this.makeRequest<ExpertAssignment[]>(GET_EXPERT_ASSIGNMENT_HISTORY_ENDPOINT, {
      method: "GET",
    });
    return response;
  }
}
