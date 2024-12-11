from openai import OpenAI
from .logger_util import setup_logger
from typing import Optional


logger = setup_logger("openai_helper", "logs/openai_helper.log")


class OpenaiHelper:
    def __init__(self, api_key: str, base_url: str):
        self.client = self.setup_client(api_key, base_url)

    def setup_client(self, api_key: str, base_url: str):
        try:
            client = OpenAI(api_key=api_key, base_url=base_url)
            return client
        except Exception as e:
            logger.error(f"Error setting up OpenAI client: {str(e)}")
            return None

    def get_prompt(self, code: str):
        """
        Retrieves the prompt for a given code.

        Args:
            code (str): The code for which the prompt needs to be retrieved.

        Returns:
            str: The prompt associated with the given code.
        """
        try:
            with open(f"prompts/{code}.txt", "r") as file:
                prompt = file.read()
            return prompt
        except Exception as e:
            logger.error(f"Error retrieving prompt for code {code}: {str(e)}")
            return None

    def get_response(
        self,
        system_prompt: Optional[str] = None,
        user_input: Optional[str] = None,
        model: Optional[str] = "gpt-4o",
        max_tokens: Optional[int] = 2048,
    ):
        """
        Retrieves the response for a given code.

        Args:
            code (str): The code for which the response needs to be retrieved.
            prompt (Optional[str], optional): The prompt to be used for generating the response. Defaults to None.

        Returns:
            str: The response generated for the given code.
        """
        try:
            response = self.client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_input},
                ],
                temperature=0,
                max_tokens=max_tokens,
                top_p=1,
                frequency_penalty=0,
                presence_penalty=0,
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error getting response: {str(e)}")
            return None

    def get_completion(
        self,
        messages: Optional[list],
        model: Optional[str] = "gpt-4o",
        max_tokens: Optional[int] = 2048,
    ):
        """
        Retrieves the response for a given code.

        Args:
            code (str): The code for which the response needs to be retrieved.
            prompt (Optional[str], optional): The prompt to be used for generating the response. Defaults to None.

        Returns:
            str: The response generated for the given code.
        """
        try:
            response = self.client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=0,
                max_tokens=max_tokens,
                top_p=1,
                frequency_penalty=0,
                presence_penalty=0,
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error getting response: {str(e)}")
            return None


import json
import requests
from urllib.parse import urljoin


class DifyHelper:
    def __init__(self, api_key, api_base) -> None:
        self.api_key = api_key
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        self.api_base = api_base

    def chat_messages(self, query):
        endpoint = "chat-messages"
        url = urljoin(self.api_base, endpoint)
        # logger.info(url)

        data = {
            "inputs": {},  
            "query": query, 
            "response_mode": "blocking", 
            "conversation_id": "", 
            "user": "system", 
        }

        response = requests.post(url, headers=self.headers, data=json.dumps(data))

        # logger.info(response.text)

        return response.json()['answer']
