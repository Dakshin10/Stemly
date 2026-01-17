import json
import os
import re
from typing import Optional, Dict, List, Any

# Assuming relative path from where main.py runs or absolute
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_FILE = os.path.join(BASE_DIR, "data", "phet_simulations.json")

class PhetService:
    def __init__(self):
        self.simulations = self._load_data()

    def _load_data(self) -> List[Dict[str, Any]]:
        if not os.path.exists(DATA_FILE):
            print(f"Warning: PhET data file not found at {DATA_FILE}")
            return []
        try:
            with open(DATA_FILE, "r") as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading PhET data: {e}")
            return []

    def find_simulation(self, topic: str) -> Optional[Dict[str, Any]]:
        """
        Finds the best matching PhET simulation for the given topic.
        Returns a dictionary with 'slug', 'title', 'url' or None.
        """
        if not topic:
            return None
        
        topic_lower = topic.lower()
        
        # 1. Direct Title Match (Best)
        for sim in self.simulations:
            if sim["title"].lower() == topic_lower:
                return self._format_result(sim)

        # 2. Keyword Match (Good)
        # Score simulations based on how many keywords match the topic words
        best_sim = None
        max_score = 0
        
        topic_words = set(re.findall(r'\w+', topic_lower))
        
        for sim in self.simulations:
            score = 0
            # Check keywords
            for keyword in sim.get("keywords", []):
                if keyword in topic_lower:
                    score += 2 # Keyword phrase match
                else:
                    # Check individual words in keyword
                    kw_words = set(re.findall(r'\w+', keyword))
                    if kw_words & topic_words:
                         score += 1
            
            # Check slug
            if sim["slug"].replace("-", " ") in topic_lower:
                score += 3

            # Check title words overlap
            title_words = set(re.findall(r'\w+', sim["title"].lower()))
            common_words = title_words.intersection(topic_words)
            score += len(common_words) * 2

            if score > max_score:
                max_score = score
                best_sim = sim
        
        if best_sim and max_score > 2: # Threshold to avoid very weak matches
             return self._format_result(best_sim)

        return None

    def _format_result(self, sim: Dict[str, Any]) -> Dict[str, Any]:
        """
        Formats the simulation data for the frontend.
        """
        base_url = "https://phet.colorado.edu/sims/html"
        slug = sim["slug"]
        url = f"{base_url}/{slug}/latest/{slug}_en.html"
        
        return {
            "type": "phet",
            "title": sim["title"],
            "url": url,
            "slug": slug,
            "subject": sim.get("subject", "general")
        }

# Global instance
phet_service = PhetService()
