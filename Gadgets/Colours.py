"""
A small script to find the closest hex colour from the ANSI list of colours
"""

import math
import re
from pathlib import Path

# Resolve path relative to this script's directory
SCRIPT_DIR = Path(__file__).parent
DEFAULT_GUIDE_PATH = SCRIPT_DIR / "ColourGuide.txt"


def hex_to_srgb(hex_str: str) -> tuple[float, float, float]:
    """Convert a hex string to normalized sRGB floats [0.0, 1.0]."""
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def hex_to_rgb_ints(hex_str: str) -> tuple[int, int, int]:
    """Convert a hex string to integer RGB tuple (0-255)."""
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i : i + 2], 16) for i in (0, 2, 4))


def srgb_to_linear(c: float) -> float:
    """Convert sRGB gamma-compressed component to linear RGB."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_oklab(hex_str: str) -> tuple[float, float, float]:
    """Convert hex color to Oklab coordinates (L, a, b)."""
    r, g, b = hex_to_srgb(hex_str)

    # 1. Expand sRGB to linear RGB
    r_lin = srgb_to_linear(r)
    g_lin = srgb_to_linear(g)
    b_lin = srgb_to_linear(b)

    # 2. Linear RGB to cone response LMS
    l = 0.4122214708 * r_lin + 0.5363325363 * g_lin + 0.0514459929 * b_lin
    m = 0.2119034982 * r_lin + 0.6806995451 * g_lin + 0.1073969566 * b_lin
    s = 0.0883024619 * r_lin + 0.2817188376 * g_lin + 0.6299787005 * b_lin

    # 3. Non-linear LMS scale
    l_prime = math.cbrt(l)
    m_prime = math.cbrt(m)
    s_prime = math.cbrt(s)

    # 4. LMS to Oklab
    L = 0.2104542553 * l_prime + 0.7936177850 * m_prime - 0.0040720468 * s_prime
    a = 1.9779984951 * l_prime - 2.4285922050 * m_prime + 0.4505937099 * s_prime
    b = 0.0259040371 * l_prime + 0.7827717662 * m_prime - 0.8086757973 * s_prime

    return (L, a, b)


def oklab_distance(
    lab1: tuple[float, float, float], lab2: tuple[float, float, float]
) -> float:
    """Calculate Euclidean distance in Oklab space."""
    return math.sqrt(
        (lab1[0] - lab2[0]) ** 2
        + (lab1[1] - lab2[1]) ** 2
        + (lab1[2] - lab2[2]) ** 2
    )


def parse_colour_guide(file_path: Path | str = DEFAULT_GUIDE_PATH) -> list[dict]:
    """Parse 'ColourGuide.txt' into a list of color objects with precomputed Oklab values."""
    palette = []
    pattern = re.compile(r"^(\d+)\s+(#[0-9a-fA-F]{6})\s+Name:\s*(.+)$")

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            match = pattern.match(line.strip())
            if match:
                number, hex_code, name = match.groups()
                palette.append(
                    {
                        "number": number,
                        "hex": hex_code,
                        "name": name,
                        "oklab": hex_to_oklab(hex_code),
                    }
                )
    return palette


def get_top_closest(
    target_hex: str,
    file_path: Path | str = DEFAULT_GUIDE_PATH,
    top_n: int = 3,
) -> list[dict]:
    """Find the top N perceptually closest colors from the palette file."""
    palette = parse_colour_guide(file_path)
    target_oklab = hex_to_oklab(target_hex)

    # Sort palette entries by Oklab distance to target
    sorted_palette = sorted(
        palette, key=lambda item: oklab_distance(target_oklab, item["oklab"])
    )

    return sorted_palette[:top_n]


# --- Interactive CLI ---
if __name__ == "__main__":
    user_input = input("Enter a hex colour code (e.g. #faa719): ").strip()

    # Prepend '#' if missing
    if user_input and not user_input.startswith("#"):
        user_input = f"#{user_input}"

    # Basic regex validation for 6-digit hex
    if re.match(r"^#[0-9a-fA-F]{6}$", user_input):
        top_matches = get_top_closest(user_input, top_n=3)

        # 24-bit Truecolor sequence for target hex input
        tr, tg, tb = hex_to_rgb_ints(user_input)
        target_truecolor = f"\x1b[38;2;{tr};{tg};{tb}m"

        # Line 1: Target color label
        print(f"\ntarget colour: {target_truecolor}{user_input}\x1b[0m")

        # Line 2: 6 blocks of target color
        print(f"{target_truecolor}█████████\x1b[0m")

        # Line 3: 2 blocks for 1st, 2nd, and 3rd closest colors
        match_blocks = ""
        for match in top_matches:
            ansi_num = match["number"]
            match_blocks += f"\x1b[38;5;{ansi_num}m███\x1b[0m"
        print(match_blocks)

        # Line 4+: List of top 3 closest colors
        print("\ntop three closest colours")
        for match in top_matches:
            ansi_num = match["number"]
            print(
                f"\x1b[38;5;{ansi_num}m{match['number']} {match['name']} {match['hex']}\x1b[0m"
            )
    else:
        print("Invalid hex code. Please enter a valid 6-digit hex code.")