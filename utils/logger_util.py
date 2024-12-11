import logging
from logging.handlers import RotatingFileHandler
import os
import logging
from logging.handlers import RotatingFileHandler
from typing import Optional, Union


def setup_logger(
    name: str, log_file: str, level: Optional[Union[int, str]] = logging.INFO
) -> logging.Logger:
    """Create a logger instance.

    Args:
        name (str): The name of the logger.
        log_file (str): The filename to store the logs.
        level (logging.Level, optional): The log level. Defaults to logging.INFO.

    Returns:
        logging.Logger: The configured Logger object.
    """
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )

    # Create a handler to write logs to a file
    handler = RotatingFileHandler(log_file, maxBytes=10000000, backupCount=5)
    handler.setFormatter(formatter)

    # Create a logger
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.addHandler(handler)

    # Create a handler to output logs to the console
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    return logger


# 示例用法
# if __name__ == "__main__":
#     logger = setup_logger('example_logger', 'example.log')
#     logger.info('这是一个信息级别的日志')
#     logger.error('这是一个错误级别的日志')
