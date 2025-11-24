"""
Locust load test for chat-backend-rails application.

User personas:
    1. NewUser - Registers for the first time (weight=1, ~10% of users)
    2. IdleUser - Polls for updates every 5 seconds (weight=4, ~40% of users)
    3. ActiveUser - Creates conversations, posts messages, browses (weight=3, ~30% of users)
    4. ExpertUser - Claims and responds to conversations (weight=2, ~20% of users)

Load test uses dynamic arrival rate that doubles every 60 seconds to find breaking point.
"""

import random
import threading
from datetime import datetime
from locust import HttpUser, task, between, LoadTestShape


# Configuration
MAX_USERS = 10000

# Sample conversation titles for creating conversations
CONVERSATION_TITLES = [
    "How to deploy Rails app?",
    "Database optimization help",
    "Authentication issues",
    "API design question",
    "Performance tuning",
    "Docker setup help",
    "Testing best practices",
    "Security concerns",
    "Caching strategies",
    "Background job processing",
]

# Sample messages for posting
SAMPLE_MESSAGES = [
    "Can you help me with this?",
    "I'm having trouble understanding the documentation.",
    "Thanks for your help!",
    "Could you provide more details?",
    "I've tried that but it didn't work.",
    "What would be the best approach here?",
    "I see, that makes sense now.",
    "Is there a better way to do this?",
    "Perfect, that solved my issue!",
    "I have a follow-up question...",
]


def auth_headers(token):
    """Generate authorization headers with JWT token."""
    return {"Authorization": f"Bearer {token}"}


class UserNameGenerator:
    """Generates unique usernames using prime number stepping to avoid collisions."""
    PRIME_NUMBERS = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]

    def __init__(self, max_users=MAX_USERS, seed=None, prime_number=None):
        self.seed = seed or random.randint(0, max_users)
        self.prime_number = prime_number or random.choice(self.PRIME_NUMBERS)
        self.current_index = -1
        self.max_users = max_users
        self.lock = threading.Lock()

    def generate_username(self):
        with self.lock:
            self.current_index += 1
            return f"user_{(self.seed + self.current_index * self.prime_number) % self.max_users}"


class UserStore:
    """Thread-safe storage for registered users and their tokens."""
    def __init__(self):
        self.used_usernames = {}
        self.username_lock = threading.Lock()
        self.conversations = []
        self.conversations_lock = threading.Lock()

    def get_random_user(self):
        with self.username_lock:
            if not self.used_usernames:
                return None
            random_username = random.choice(list(self.used_usernames.keys()))
            return self.used_usernames[random_username]

    def store_user(self, username, auth_token, user_id):
        with self.username_lock:
            self.used_usernames[username] = {
                "username": username,
                "auth_token": auth_token,
                "user_id": user_id
            }
            return self.used_usernames[username]

    def add_conversation(self, conversation_id):
        with self.conversations_lock:
            self.conversations.append(conversation_id)

    def get_random_conversation(self):
        with self.conversations_lock:
            if not self.conversations:
                return None
            return random.choice(self.conversations)


user_store = UserStore()
user_name_generator = UserNameGenerator(max_users=MAX_USERS)


class ChatBackend:
    """
    Base class for all user personas.
    Provides common authentication and API interaction methods.
    """

    def login(self, username, password):
        """Login an existing user."""
        response = self.client.post(
            "/auth/login",
            json={"username": username, "password": password},
            name="/auth/login"
        )
        if response.status_code == 200:
            data = response.json()
            return user_store.store_user(username, data.get("token"), data.get("user", {}).get("id"))
        return None

    def register(self, username, password):
        """Register a new user."""
        response = self.client.post(
            "/auth/register",
            json={"username": username, "password": password},
            name="/auth/register"
        )
        if response.status_code == 201:
            data = response.json()
            return user_store.store_user(username, data.get("token"), data.get("user", {}).get("id"))
        return None

    def check_conversation_updates(self, user):
        """Check for conversation updates."""
        params = {"userId": user.get("user_id")}
        if hasattr(self, 'last_check_time') and self.last_check_time:
            params["since"] = self.last_check_time.isoformat()

        response = self.client.get(
            "/api/conversations/updates",
            params=params,
            headers=auth_headers(user.get("auth_token")),
            name="/api/conversations/updates"
        )

        return response.status_code == 200

    def check_message_updates(self, user):
        """Check for message updates."""
        params = {"userId": user.get("user_id")}
        if hasattr(self, 'last_check_time') and self.last_check_time:
            params["since"] = self.last_check_time.isoformat()

        response = self.client.get(
            "/api/messages/updates",
            params=params,
            headers=auth_headers(user.get("auth_token")),
            name="/api/messages/updates"
        )

        return response.status_code == 200

    def check_expert_queue_updates(self, user):
        """Check for expert queue updates."""
        params = {"expertId": user.get("user_id")}
        if hasattr(self, 'last_check_time') and self.last_check_time:
            params["since"] = self.last_check_time.isoformat()

        response = self.client.get(
            "/api/expert-queue/updates",
            params=params,
            headers=auth_headers(user.get("auth_token")),
            name="/api/expert-queue/updates"
        )

        return response.status_code == 200

    def get_conversations(self, user):
        """Get all conversations for the user."""
        response = self.client.get(
            "/conversations",
            headers=auth_headers(user.get("auth_token")),
            name="/conversations"
        )
        if response.status_code == 200:
            return response.json()
        return []

    def get_conversation(self, user, conversation_id):
        """Get a specific conversation."""
        response = self.client.get(
            f"/conversations/{conversation_id}",
            headers=auth_headers(user.get("auth_token")),
            name="/conversations/[id]"
        )
        return response.status_code == 200

    def create_conversation(self, user, title):
        """Create a new conversation."""
        response = self.client.post(
            "/conversations",
            json={"title": title},
            headers=auth_headers(user.get("auth_token")),
            name="/conversations"
        )
        if response.status_code == 201:
            data = response.json()
            conversation_id = data.get("id")
            if conversation_id:
                user_store.add_conversation(conversation_id)
            return data
        return None

    def get_messages(self, user, conversation_id):
        """Get messages for a conversation."""
        response = self.client.get(
            f"/conversations/{conversation_id}/messages",
            headers=auth_headers(user.get("auth_token")),
            name="/conversations/[id]/messages"
        )
        if response.status_code == 200:
            return response.json()
        return []

    def post_message(self, user, conversation_id, content):
        """Post a message to a conversation."""
        response = self.client.post(
            "/messages",
            json={"conversationId": conversation_id, "content": content},
            headers=auth_headers(user.get("auth_token")),
            name="/messages"
        )
        return response.status_code == 201

    def get_expert_queue(self, user):
        """Get the expert queue."""
        response = self.client.get(
            "/expert/queue",
            headers=auth_headers(user.get("auth_token")),
            name="/expert/queue"
        )
        if response.status_code == 200:
            return response.json()
        return None

    def claim_conversation(self, user, conversation_id):
        """Claim a conversation as an expert."""
        response = self.client.post(
            f"/expert/conversations/{conversation_id}/claim",
            headers=auth_headers(user.get("auth_token")),
            name="/expert/conversations/[id]/claim"
        )
        return response.status_code == 200

    def get_expert_profile(self, user):
        """Get the expert profile."""
        response = self.client.get(
            "/expert/profile",
            headers=auth_headers(user.get("auth_token")),
            name="/expert/profile"
        )
        return response.status_code == 200


class NewUser(HttpUser, ChatBackend):
    """
    Persona: A brand new user registering for the first time.
    Registers, creates their first conversation, and posts initial message.
    Weight: 1 (~10% of simulated users)
    """
    weight = 1
    wait_time = between(1, 3)

    def on_start(self):
        """Register a new user."""
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.register(username, password)
        if not self.user:
            # If registration fails (user exists), try to login
            self.user = self.login(username, password)
        if not self.user:
            raise Exception(f"Failed to register or login user {username}")

    @task(3)
    def create_first_conversation(self):
        """New user creates their first conversation."""
        title = random.choice(CONVERSATION_TITLES)
        conversation = self.create_conversation(self.user, title)
        if conversation:
            # Post initial message
            self.post_message(self.user, conversation.get("id"), random.choice(SAMPLE_MESSAGES))

    @task(1)
    def browse_conversations(self):
        """New user browses their conversations."""
        self.get_conversations(self.user)


class IdleUser(HttpUser, ChatBackend):
    """
    Persona: A user that logs in and is idle but their browser polls for updates.
    Checks for message updates, conversation updates, and expert queue updates every 5 seconds.
    Weight: 4 (~40% of simulated users)
    """
    weight = 4
    wait_time = between(5, 5)  # Check every 5 seconds

    def on_start(self):
        """Called when a simulated user starts."""
        self.last_check_time = None
        self.user = user_store.get_random_user()
        if not self.user:
            # Fallback: register a new user if store is empty
            username = user_name_generator.generate_username()
            password = username
            self.user = self.register(username, password)

    @task
    def poll_for_updates(self):
        """Poll for all types of updates."""
        # Check conversation updates
        self.check_conversation_updates(self.user)

        # Check message updates
        self.check_message_updates(self.user)

        # Check expert queue updates
        self.check_expert_queue_updates(self.user)

        # Update last check time
        self.last_check_time = datetime.utcnow()


class ActiveUser(HttpUser, ChatBackend):
    """
    Persona: An active user that creates conversations, posts messages, and browses.
    Weight: 3 (~30% of simulated users)
    """
    weight = 3
    wait_time = between(1, 5)

    def on_start(self):
        """Login or register the user."""
        self.last_check_time = None
        self.user = user_store.get_random_user()
        if not self.user:
            # Fallback: register a new user if store is empty
            username = user_name_generator.generate_username()
            password = username
            self.user = self.register(username, password)

    @task(3)
    def browse_conversations(self):
        """Browse all conversations."""
        conversations = self.get_conversations(self.user)
        if conversations and len(conversations) > 0:
            # View a random conversation's details
            conv = random.choice(conversations)
            self.get_conversation(self.user, conv.get("id"))

    @task(2)
    def create_new_conversation(self):
        """Create a new conversation."""
        title = random.choice(CONVERSATION_TITLES)
        self.create_conversation(self.user, title)

    @task(4)
    def post_message_to_conversation(self):
        """Post a message to an existing conversation."""
        conversation_id = user_store.get_random_conversation()
        if conversation_id:
            content = random.choice(SAMPLE_MESSAGES)
            self.post_message(self.user, conversation_id, content)

    @task(3)
    def read_messages(self):
        """Read messages in a conversation."""
        conversation_id = user_store.get_random_conversation()
        if conversation_id:
            self.get_messages(self.user, conversation_id)

    @task(2)
    def poll_updates(self):
        """Occasionally poll for updates."""
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.last_check_time = datetime.utcnow()


class ExpertUser(HttpUser, ChatBackend):
    """
    Persona: An expert user that claims and responds to conversations.
    Fetches expert queue, claims conversations, reads messages, and posts responses.
    Weight: 2 (~20% of simulated users)
    """
    weight = 2
    wait_time = between(2, 8)

    def on_start(self):
        """Login or register the expert user."""
        self.last_check_time = None
        self.user = user_store.get_random_user()
        if not self.user:
            # Fallback: register a new user if store is empty
            username = user_name_generator.generate_username()
            password = username
            self.user = self.register(username, password)

    @task(4)
    def respond_to_conversations(self):
        """
        Main expert workflow: fetch queue, read messages, post responses.
        This chains multiple requests to simulate real expert behavior.
        """
        # 1. Fetch the expert queue
        queue = self.get_expert_queue(self.user)
        if not queue:
            return

        # 2. Get assigned conversations (conversations this expert has claimed)
        assigned = queue.get("assignedConversations", [])

        if not assigned:
            # No assigned conversations, try to claim one from waiting
            waiting = queue.get("waitingConversations", [])
            if waiting:
                conv = random.choice(waiting)
                self.claim_conversation(self.user, conv.get("id"))
            return

        # 3. Choose random subset of assigned conversations (up to 3)
        num_to_respond = min(len(assigned), random.randint(1, 3))
        conversations_to_respond = random.sample(assigned, num_to_respond)

        # 4. For each conversation: load messages and post a response
        for conv in conversations_to_respond:
            conv_id = conv.get("id")

            # Load messages for this conversation
            self.get_messages(self.user, conv_id)

            # Post a response message
            response = random.choice(SAMPLE_MESSAGES)
            self.post_message(self.user, conv_id, response)

    @task(2)
    def claim_waiting_conversation(self):
        """Check queue and claim a waiting conversation."""
        queue = self.get_expert_queue(self.user)
        if queue:
            waiting = queue.get("waitingConversations", [])
            if waiting:
                conv = random.choice(waiting)
                self.claim_conversation(self.user, conv.get("id"))

    @task(1)
    def view_expert_profile(self):
        """View own expert profile."""
        self.get_expert_profile(self.user)

    @task(2)
    def poll_for_updates(self):
        """Poll for updates relevant to expert."""
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.check_expert_queue_updates(self.user)
        self.last_check_time = datetime.utcnow()


class StepLoadShape(LoadTestShape):
    """
    Dynamic arrival rate load test shape.
    Doubles the spawn rate every 60 seconds to find breaking point.

    Stages:
        - 60s: 2 users/sec (target: ~120 users)
        - 60s: 4 users/sec (target: ~360 users)
        - 60s: 8 users/sec (target: ~840 users)
        - 60s: 16 users/sec (target: ~1800 users)
        - 60s: 32 users/sec (target: ~3720 users)
        - 60s: 64 users/sec (target: ~7560 users)
        - 60s: 128 users/sec (continues until breaking point)
    """

    stages = [
        {"duration": 60, "users": 120, "spawn_rate": 2},
        {"duration": 120, "users": 360, "spawn_rate": 4},
        {"duration": 180, "users": 840, "spawn_rate": 8},
        {"duration": 240, "users": 1800, "spawn_rate": 16},
        {"duration": 300, "users": 3720, "spawn_rate": 32},
        {"duration": 360, "users": 7560, "spawn_rate": 64},
        {"duration": 420, "users": 15000, "spawn_rate": 128},
    ]

    def tick(self):
        run_time = self.get_run_time()

        for stage in self.stages:
            if run_time < stage["duration"]:
                tick_data = (stage["users"], stage["spawn_rate"])
                return tick_data

        # After all stages, maintain last stage
        return (self.stages[-1]["users"], self.stages[-1]["spawn_rate"])
