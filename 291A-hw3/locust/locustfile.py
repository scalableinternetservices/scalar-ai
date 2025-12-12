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

# Expert bio to knowledge base URL mapping
EXPERT_BIOS = {
    "Gaming & Interactive Media expert": {
        "bio": "I specialize in video game development and design, with deep knowledge of action RPGs, 3D platformers, and MOBAs. I have extensive experience with game design principles, user feedback loops, and performance optimization. I can help with questions about League of Legends, Mario Odyssey, game mechanics, and building engaging gameplay experiences.",
        "urls": ["https://edisonnchen.github.io/"]
    },
    "Full-Stack Web Development expert": {
        "bio": "I'm a full-stack web developer specializing in React, Node.js, Python, and modern JavaScript frameworks. I can help with frontend development, backend API design, database optimization, and building scalable web applications. I have experience with responsive design, state management, and RESTful services.",
        "urls": ["https://edisonnchen.github.io/"]
    },
    "Machine Learning expert": {
        "bio": "I specialize in machine learning and data science applications using TensorFlow, PyTorch, and various ML frameworks. I can help with model training, neural networks, data preprocessing, and deploying ML models in production. I have experience with computer vision, NLP, and predictive analytics.",
        "urls": ["https://edisonnchen.github.io/"]
    },
    "Computer Architecture expert": {
        "bio": "I have deep knowledge of computer architecture including x86, ARM, and RISC-V. I can help with low-level programming, assembly language, processor design, memory hierarchies, and performance optimization at the hardware level.",
        "urls": ["https://edisonnchen.github.io/"]
    },
    "Board Games enthusiast": {
        "bio": "I'm passionate about modern board games, particularly high-interaction strategy games like Dune Imperium and Sidereal Confluence. I can recommend games, explain rules, discuss strategy, and help you find the perfect game for your group. I specialize in economic games, area control, and card drafting mechanics.",
        "urls": ["https://jamespflaging.github.io/interest/"]
    },
    "Photography expert": {
        "bio": "I specialize in photography techniques, camera equipment, composition, and post-processing. I can help with both digital and film photography, lighting setups, portrait photography, landscape photography, and photo editing workflows using Adobe Lightroom and Photoshop.",
        "urls": ["https://jamespflaging.github.io/interest/", "https://adyahrastogi.github.io/"]
    },
    "Triathlon coach": {
        "bio": "I'm experienced in triathlon training, covering swimming, cycling, and running. I can help with training plans, nutrition strategies, race preparation, injury prevention, and balancing endurance training with recovery. I specialize in helping beginners complete their first triathlon.",
        "urls": ["https://jamespflaging.github.io/interest/"]
    },
    "Ergonomic Keyboards specialist": {
        "bio": "I'm an expert in ergonomic keyboards, including split keyboards, tenting, ortholinear layouts, and alternative keyboard layouts like Colemak DH. I use a ZSA Moonlander MK1 daily and can help with keyboard selection, layout customization, and transitioning from traditional keyboards to ergonomic setups.",
        "urls": ["https://ononymous.github.io/index.html"]
    },
    "Cars enthusiast": {
        "bio": "I'm passionate about cars, particularly Japanese sports cars like the Toyota Supra, Porsche 911, and custom builds like RWB. I can discuss car modifications, performance tuning, reliability comparisons, and help you choose your next car. I have strong opinions on hybrids vs electric vehicles.",
        "urls": ["https://ononymous.github.io/index.html", "https://adyahrastogi.github.io/"]
    },
    "Japan travel expert": {
        "bio": "I have extensive experience traveling in Japan, including solo travel and hidden gems. I can help with trip planning, recommend off-the-beaten-path destinations like Rokko mountain, discuss Japanese culture and traditions, and provide insider tips for authentic experiences beyond the tourist hotspots.",
        "urls": ["https://ononymous.github.io/index.html"]
    },
    "Coffee expert": {
        "bio": "I'm knowledgeable about coffee, from bean selection (Arabica vs Robusta) to brewing methods and equipment. I can help with coffee preparation techniques, espresso drinks, coffee storage, and understanding the differences between various brewing methods and coffee origins.",
        "urls": ["https://wesleytruong.github.io/"]
    },
    "Mechanical Keyboards expert": {
        "bio": "I specialize in mechanical keyboards, including switch types, keycap profiles, custom builds, and keyboard layouts. I can help you choose switches, build your first custom keyboard, understand group buys, and optimize your typing experience with the perfect keyboard setup.",
        "urls": ["https://wesleytruong.github.io/", "https://hugolin0.github.io/cs291a-project1/"]
    },
    "Neovim expert": {
        "bio": "I'm experienced with Neovim configuration, plugins, Lua scripting, and building an efficient development environment. I can help with migrating from Vim, setting up LSP, configuring plugins, and optimizing your Neovim workflow for maximum productivity.",
        "urls": ["https://wesleytruong.github.io/"]
    },
    "Pop Mart collector": {
        "bio": "I'm passionate about Pop Mart collectible art toys, blind boxes, and character series like Labubu and Dimoo. I can help with collecting strategies, understanding rarity and secret figures, trading tips, and identifying authentic figures. I'm especially knowledgeable about the Monsters series.",
        "urls": ["https://hugolin0.github.io/cs291a-project1/"]
    },
    "Fountain Pens enthusiast": {
        "bio": "I'm knowledgeable about fountain pens, including nib sizes, ink types, pen maintenance, and collecting vintage pens. I can help you choose your first fountain pen, recommend inks, troubleshoot writing issues, and understand the differences between various pen brands and filling mechanisms.",
        "urls": ["https://hugolin0.github.io/cs291a-project1/"]
    },
    "Vegetarian Weightlifting coach": {
        "bio": "I specialize in weightlifting and strength training for vegetarians. I can help with plant-based protein sources, meal planning for muscle gain, supplement recommendations like creatine, and designing effective training programs. I understand the unique challenges vegetarians face in building muscle.",
        "urls": ["https://adyahrastogi.github.io/"]
    },
    "Stationery & Journaling expert": {
        "bio": "I'm passionate about stationery, journaling techniques, bullet journaling, and paper goods. I can recommend notebooks, pens, and organizing systems, and help you develop effective journaling habits for productivity, creativity, or mental wellness.",
        "urls": ["https://adyahrastogi.github.io/"]
    },
    "Crocheting instructor": {
        "bio": "I'm experienced in crocheting techniques, patterns, yarn selection, and project planning. I can help beginners learn basic stitches, recommend patterns for different skill levels, troubleshoot common mistakes, and suggest yarn types for various projects.",
        "urls": ["https://adyahrastogi.github.io/"]
    },
    "Drawing instructor": {
        "bio": "I teach drawing fundamentals including perspective, shading, composition, and figure drawing. I can help with digital and traditional drawing techniques, recommend tools and materials, and provide guidance on developing your artistic style and improving your skills.",
        "urls": ["https://adyahrastogi.github.io/"]
    }
}

# Questions that can be auto-answered (FAQ exists) - 33%
FAQ_ANSWERABLE_QUESTIONS = {
    # Gaming
    "What games do you recommend for competitive play?": "I mainly play League of Legends and Brawl Stars competitively, but I enjoy ranked ladders more for learning than pure competition. What aspect of competitive gaming interests you most?",
    "How do you balance gaming with other activities?": "I use time-boxed sessions and prioritize fitness and sleep. Playing socially also helps keep the hobby balanced. What's your current struggle with balance?",
    "What's your take on mobile gaming?": "I enjoy Brawl Stars and Clash Royale on mobile. They're great for quick sessions and have surprisingly deep gameplay. Are you looking for mobile game recommendations?",
    
    # Board Games
    "What board game should I start with?": "For exploring modern board games, I'd recommend Irish Gauge (a train game) or Race for the Galaxy (space-age card game). Both are accessible yet strategic. What's your experience level?",
    "Where can I buy board games affordably?": "I strongly recommend Facebook marketplace - you can get games for 20-80% off! Amazon works for new games, or find a local board game store. What games are you looking for?",
    "What's a good 2-player board game?": "I love 7 Wonders Duel - it's a 20-minute card drafting game that's easy to learn but has great depth. I've even played it with my parents! What kind of games do you enjoy?",
    "Can you recommend games for large groups?": "For larger groups with mixed skill levels, I'd suggest Liars Dice or Wizard - both are inclusive and fun! How many players are you planning for?",
    
    # Coffee
    "What's the difference between Arabica and Robusta?": "Arabica beans have a sweeter, softer taste with fruit and berry tones. Robusta is stronger and harsher with grain-like overtones. Which flavor profile appeals to you?",
    "How should I store coffee beans?": "Store them in an airtight container at room temperature, away from heat, light, and moisture. Never refrigerate! How long do your beans typically last?",
    "What's the ideal water temperature for brewing?": "The ideal temperature is between 195°F and 205°F (90°C-96°C). Too hot burns the coffee, too cold under-extracts it. What brewing method do you use?",
    "What's the difference between latte and cappuccino?": "A cappuccino has equal parts espresso, steamed milk, and foam. A latte has more steamed milk and just a light layer of foam. Which do you prefer?",
    
    # Ergonomic Keyboards
    "Why should I use an ergonomic keyboard?": "They reduce strain and improve comfort, especially if you have typing issues. I switched because of bad spacebar habits. What discomfort are you experiencing?",
    "What keyboard do you use daily?": "I use a ZSA Moonlander MK1 with split, tenting, and ortholinear design. It has thumb clusters which are game-changing. What features interest you most?",
    "What's an ortholinear layout?": "Keys arranged in a grid pattern instead of staggered rows. It minimizes wrist movement and increases efficiency. The learning curve is steep but worth it. Ready to try something new?",
    "What keyboard should I get as my endgame?": "I'm eyeing either a minimal Corne or a custom 3D printed Dactyl Manuform. Both offer different philosophies of ergonomics. What's your priority - portability or ultimate comfort?",
    
    # Cars
    "What's your dream car?": "My realistic dream is the upcoming Toyota Supra MK6 - reliable, stylish, and not too expensive. Unrealistically, an RWB Porsche 911 widebody. What's yours?",
    "Is the Supra MK5 a real Toyota?": "No, it's basically a BMW. That's why I'm waiting for the MK6 which should be more Toyota. Are you considering buying one?",
    "Should I get hybrid or electric?": "Hybrids are better now - better reliability, efficiency, and range. I'd only consider electric when solid-state batteries are mainstream. What's your use case?",
    "What car do you currently drive?": "I drive a Toyota RAV4 2017 - most comfortable and reliable car ever. It's practical and dependable. What are you looking for in a car?",
    
    # Japan Travel
    "What's the best season to visit Japan?": "Spring! Cherry blossoms bloom late March to early April, and the temperature is perfect. Book early though, it's popular. When are you planning to go?",
    "Can you recommend a hidden gem in Japan?": "Rokko mountain in Kobe, Hyogo - one hostel, gondola access only, remote but developed enough. It's magical for solo travelers. Are you planning a solo trip?",
    "What's your favorite Japanese city?": "Kyoto! Perfect blend of traditional and modern. Pro tip: book an Airbnb near Fushimi Inari and visit at night to avoid crowds. Have you been before?",
    "Where should I go to avoid tourists?": "Visit less popular prefectures for authentic experiences. The current tourism boom makes hidden areas even more special. What kind of experience are you looking for?",
    
    # Pop Mart
    "What is Pop Mart?": "Pop Mart creates collectible art toys sold in blind boxes - you don't know which figure you get until opening! It's exciting and addictive. Ever collected anything?",
    "Why is Labubu so popular?": "Labubu from the Monsters series by Kasing Lung has a unique design - mischievous monster with rabbit ears. The character just resonates with people! Have you seen one in person?",
    "What's your favorite Pop Mart character?": "Dimoo! I love his big eyes, cloud-like hair, and dreamy adventures. Each series tells a story. Do you have a favorite character?",
    "Should I buy single boxes or a case?": "Singles for the surprise thrill! A case (12 boxes) guarantees all standard figures if you want to complete a series. What's your collecting style?",
    
    # Vegetarian Weightlifting
    "Can vegetarians build muscle effectively?": "Yes! Muscle growth depends on progressive training and sufficient protein (0.7-1g per pound body weight). With proper planning, vegetarians build muscle just as well. What's your current protein intake?",
    "What are good vegetarian protein sources?": "Legumes, tofu, tempeh, seitan, quinoa, eggs, Greek yogurt, cottage cheese, and nutritional yeast. Variety is key! What proteins do you currently eat?",
    "Should I use protein powder as a vegetarian?": "Not strictly necessary if you prioritize protein in meals, but it's convenient for busy days or post-workout. I use it occasionally. Do you have trouble hitting protein goals?",
    "What about creatine for vegetarians?": "Yes! Most creatine is synthetic and vegetarian-friendly. It's especially helpful for vegetarians since we don't get it from diet naturally. It improves strength and cognitive function. Have you tried it?",
    
    # Mechanical Keyboards
    "What mechanical keyboard should I get?": "Depends on your use case! For typing, tactile switches like Browns. For gaming, linear like Reds. Budget and size matter too. What's your main use?",
    "What's the difference between keyboard switches?": "Linear (smooth), Tactile (bump feedback), Clicky (audible click). Each feels completely different. Sound and feel are personal preference. Want to try a switch tester?",
    
    # Neovim  
    "How do I get started with Neovim?": "Start with a minimal config, add plugins gradually. Learn Lua basics and understand lazy loading. Don't copy entire configs blindly! What's your current editor?",
    "Should I migrate from Vim to Neovim?": "If you want better plugin ecosystem, Lua configuration, and built-in LSP support - yes! Migration is gradual. What Vim features do you rely on most?"
}

# Questions that are expertise-related but not FAQ-answerable - 33%
EXPERTISE_ONLY_QUESTIONS = {
    # Gaming
    "How do I improve at League of Legends?": "I need specific help climbing ranked. I main support and struggle with map awareness and deciding when to roam. Any tips for climbing in lower elos?",
    "What makes a good game design?": "I'm working on my first indie game and want to understand what makes games compelling. What are the key elements of good game design that keep players engaged?",
    
    # Web Development
    "How do I optimize React performance?": "My React app is getting slow with large lists. I've tried useMemo but still seeing lag. What are the best practices for handling large datasets in React?",
    "What's the best way to structure a Node.js API?": "I'm building a REST API with Node.js and Express. What folder structure, middleware patterns, and error handling strategies do you recommend for scalability?",
    
    # Machine Learning
    "How do I prevent overfitting in neural networks?": "My model performs great on training data but poorly on validation. I've tried dropout and regularization. What else should I consider to improve generalization?",
    "What's the best approach for small datasets in ML?": "I have limited training data for an image classification task. Should I use transfer learning, data augmentation, or something else? What works best?",
    
    # Board Games
    "What's your strategy for Dune Imperium?": "I keep losing at Dune Imperium and feel like I'm missing key strategies. How do you balance deck building with board control? Any tips for winning?",
    "How do I convince friends to try modern board games?": "My friends only know Monopoly and Catan. How do I introduce them to better games without overwhelming them? What's a good gateway game?",
    
    # Photography
    "What camera settings for night photography?": "I'm trying to photograph stars and cityscapes at night but my photos come out blurry or too dark. What ISO, aperture, and shutter speed should I use?",
    "How do I get into film photography?": "I want to try film photography but it seems expensive and complicated. What camera should I start with and where do I get film developed?",
    
    # Triathlon
    "How do I train for my first triathlon?": "I can swim, bike, and run separately but never combined them. How should I structure my training for a sprint triathlon in 3 months?",
    "What's the best nutrition strategy for endurance?": "I bonk during long training sessions. What should I eat before, during, and after long workouts? How do I fuel for race day?",
    
    # Cars
    "Should I buy a used Supra or new Civic Type R?": "I'm deciding between a used MK4 Supra or new Civic Type R. Similar price range. Which would you choose for a daily driver that's also fun?",
    "How do I get into car modifications?": "I want to modify my car but don't know where to start. What mods give the best bang for buck? Should I do cosmetic or performance first?",
    
    # Japan
    "How do I plan a month-long solo trip to Japan?": "I want to solo travel Japan for a month like you did. How do I plan an itinerary? What's a good budget? Any tips for traveling alone?",
    "What should I know about Japanese etiquette?": "I'm visiting Japan for the first time and worried about making cultural mistakes. What are the most important etiquette rules I should know?",
    
    # Coffee
    "What espresso machine should I buy?": "I want to make café-quality espresso at home. What's a good entry-level machine that won't break the bank but produces great results?",
    "How do I dial in espresso properly?": "I got an espresso machine but my shots are either too bitter or sour. How do I dial in the grind size and extraction time correctly?",
    
    # Ergonomic Keyboards
    "Should I learn Colemak or stick with QWERTY?": "I'm considering learning Colemak for my new ergonomic keyboard. Is the learning curve worth it? How long did it take you to become proficient?",
    "How do I transition to a split keyboard?": "I just got a split keyboard and can barely type. How long does adaptation take? Any tips for speeding up the learning process?",
    
    # Neovim
    "What's your Neovim plugin setup?": "I'm rebuilding my Neovim config from scratch. What plugins do you consider essential? How do you organize your config files?",
    "How do I set up LSP in Neovim?": "I'm confused about LSP setup in Neovim. What's the difference between nvim-lspconfig, null-ls, and Mason? Which do I actually need?",
    
    # Mechanical Keyboards
    "Should I build or buy my first custom keyboard?": "I'm interested in custom keyboards but overwhelmed by options. Should I buy a prebuilt first or dive into building my own?",
    "What's the best switch for typing all day?": "I type 8+ hours daily and want to reduce fatigue. What switch type and actuation force would you recommend for all-day typing comfort?",
    
    # Vegetarian Weightlifting
    "What's a good vegetarian bulking meal plan?": "I'm trying to bulk as a vegetarian but struggling to eat enough calories and protein. Can you suggest a daily meal plan that hits macros?",
    "How do I prevent iron deficiency while lifting?": "I'm worried about iron deficiency affecting my training. What vegetarian iron sources are best and how do I maximize absorption?",
    
    # Pop Mart
    "How do I start collecting Pop Mart figures?": "I'm new to Pop Mart and overwhelmed by all the series. Where should I start? How do I avoid overspending on this hobby?",
    "Where can I trade Pop Mart figures?": "I have duplicate figures and want to trade. Where's the best place to find other collectors? How do I ensure safe trades?",
    
    # Fountain Pens
    "What fountain pen should I buy first?": "I've never used a fountain pen but want to try. What's a good beginner pen that's not too expensive but writes well?",
    "How do I maintain my fountain pens?": "My fountain pen is skipping and feels scratchy. How do I clean it properly? What maintenance should I do regularly?"
}

# Questions unrelated to anyone's expertise - 33%
UNRELATED_QUESTIONS = {
    "How do I fix my washing machine?": "My washing machine is making a loud banging noise during the spin cycle. I've checked for unbalanced loads but the problem persists. What could be wrong?",
    "What's the best way to learn Spanish?": "I want to become fluent in Spanish for travel. Should I use apps like Duolingo, take classes, or find a language exchange partner? What worked for you?",
    "How do I start investing in stocks?": "I'm 25 and want to start investing but know nothing about stocks. Should I use index funds, individual stocks, or a robo-advisor? What's a good starting strategy?",
    "Can you recommend good hiking trails?": "I'm looking for day hikes within 2 hours of Los Angeles. I'm intermediate level and prefer scenic views. Any recommendations?",
    "How do I prepare for a job interview?": "I have a job interview next week for a project manager position. What questions should I prepare for? How do I make a strong impression?",
    "What's the best way to organize my closet?": "My closet is a mess and I can't find anything. What organization systems work best? Should I use Marie Kondo method or something else?",
    "How do I train my dog to stop barking?": "My dog barks at everything - people, other dogs, delivery trucks. Training hasn't helped. What techniques work for excessive barking?",
    "What's a good beginner guitar?": "I want to learn guitar but don't want to spend too much on my first instrument. What's a good beginner acoustic guitar under $300?",
    "How do I deal with noisy neighbors?": "My upstairs neighbors are extremely loud late at night. I've talked to them but nothing changed. What are my options?",
    "What's the best way to meal prep?": "I want to meal prep for the week to save time and eat healthier. What containers should I use? How do I keep food fresh?",
    "How do I remove coffee stains from carpet?": "I spilled coffee on my white carpet and the stain won't come out. I've tried various cleaners with no luck. Any secret techniques?",
    "What's a good beginner workout routine?": "I haven't exercised in years and want to start. What's a good beginner routine that won't overwhelm me? How many days per week?",
    "How do I start a podcast?": "I want to start a podcast about local history. What equipment do I need? What platforms should I use for hosting and distribution?",
    "What's the best city for digital nomads?": "I'm a remote worker considering relocating abroad for a year. What cities are best for digital nomads in terms of cost, internet, and community?",
    "How do I write a resume for career change?": "I'm changing careers from teaching to tech. How do I write a resume that highlights transferable skills? What should I emphasize?",
    "What's a good beginner sewing project?": "I just got a sewing machine and want to start with something simple. What's a good first project to learn basic techniques?",
    "How do I start a vegetable garden?": "I want to start growing vegetables in my backyard but have no experience. What vegetables are easiest for beginners? When should I plant?",
    "What's the best way to learn piano?": "I'm 30 and want to learn piano. Is it too late? Should I get a teacher or use online resources? What keyboard should I start with?",
    "How do I reduce my carbon footprint?": "I want to live more sustainably but don't know where to start. What changes have the biggest impact? What's realistic for everyday life?",
    "What's a good side hustle?": "I need extra income and have evenings/weekends free. What are realistic side hustles that don't require huge upfront investment?",
    "How do I make sourdough bread?": "I want to start making sourdough bread at home. How do I create and maintain a starter? What's the basic process?",
    "What's the best way to learn touch typing?": "I'm a slow typer and want to improve. What's the best method to learn touch typing? How long does it typically take?",
    "How do I start freelance writing?": "I want to freelance write but don't know how to find clients or set rates. Where do I start? What platforms are best for beginners?",
    "What's a good laptop for college?": "I'm starting college and need a laptop for general use - notes, essays, web browsing. What specs do I actually need? What's a good budget?",
    "How do I negotiate salary?": "I got a job offer but the salary seems low. How do I negotiate without seeming ungrateful? What's a good strategy?"
}

# Sample messages for ongoing conversations
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
        if response.status_code == 200:
            return response.json()
        return None

    def update_expert_profile(self, user, bio, knowledge_base_links):
        """Update the expert profile with bio and knowledge base links."""
        response = self.client.put(
            "/expert/profile",
            json={"bio": bio, "knowledge_base_links": knowledge_base_links},
            headers=auth_headers(user.get("auth_token")),
            name="/expert/profile"
        )
        return response.status_code == 200

    def create_conversation_with_message(self, user, question_data):
        """Create a conversation and post the initial message."""
        title, message = question_data
        conversation = self.create_conversation(user, title)
        if conversation:
            conversation_id = conversation.get("id")
            # Post initial message
            if self.post_message(user, conversation_id, message):
                return conversation_id
        return None

    def select_random_question(self):
        """Select a random question with weighted distribution (33% each category)."""
        category = random.choices(
            ["faq", "expertise", "unrelated"],
            weights=[33, 33, 34],  # Sums to 100
            k=1
        )[0]
        
        if category == "faq":
            questions = FAQ_ANSWERABLE_QUESTIONS
        elif category == "expertise":
            questions = EXPERTISE_ONLY_QUESTIONS
        else:
            questions = UNRELATED_QUESTIONS
        
        title = random.choice(list(questions.keys()))
        return (title, questions[title])


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
        """New user creates their first conversation with realistic question."""
        question_data = self.select_random_question()
        self.create_conversation_with_message(self.user, question_data)

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
        """Create a new conversation with realistic question."""
        question_data = self.select_random_question()
        self.create_conversation_with_message(self.user, question_data)

    @task(4)
    def post_message_to_conversation(self):
        """Post a message to a randomly selected conversation."""
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
    80% start with a bio and knowledge base links, 20% start without.
    Weight: 2 (~20% of simulated users)
    """
    weight = 2
    wait_time = between(2, 8)

    def on_start(self):
        """Login or register the expert user and set up their profile."""
        self.last_check_time = None
        self.user = user_store.get_random_user()
        if not self.user:
            # Fallback: register a new user if store is empty
            username = user_name_generator.generate_username()
            password = username
            self.user = self.register(username, password)
        
        # 80% chance to set up expert profile with bio and knowledge base
        if random.randint(1, 100) <= 80:
            self.setup_expert_profile()

    def setup_expert_profile(self):
        """Set up expert profile with bio and knowledge base links."""
        # Select a random expertise area
        expertise = random.choice(list(EXPERT_BIOS.keys()))
        bio_data = EXPERT_BIOS[expertise]
        
        bio = bio_data["bio"]
        knowledge_base_links = bio_data["urls"]
        
        # Update the expert profile
        self.update_expert_profile(self.user, bio, knowledge_base_links)

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

    @task(1)
    def update_profile_occasionally(self):
        """Occasionally update expert profile (triggers FAQ generation and scraping)."""
        # 10% chance to update profile
        if random.randint(1, 100) <= 10:
            self.setup_expert_profile()

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
