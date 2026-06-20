"""TajweedEngine — localizes every rule occurrence from the verse text alone.

This is the component that lets every later violation carry `char_index`
(the foundation of Feedback Grounding Rate). It answers, from text only:
"which Tajweed rule occurs WHERE, and on which Arabic character?"

It does NOT judge correctness — that is the rule engine (Class A) or the
acoustic classifier (Class B). Engine localizes; the judge decides.
"""
from __future__ import annotations

from dataclasses import dataclass

from . import phonology as P


@dataclass
class Expectation:
    rule: str               # Izhar | Idgham | Iqlab | Ikhfaa | Ghunnah | Madd
    rule_class: str         # "A" (text-determinable) or "B" (acoustic)
    char: str               # the Arabic letter the rule sits on
    char_index: int         # index into the original verse string  -> enables FGR
    following_char: str | None
    detail: str
    with_ghunnah: bool | None = None


class TajweedEngine:
    def expected(self, verse_text: str) -> list[Expectation]:
        """Return every rule occurrence in the verse, in reading order."""
        letters = P.parse_letters(verse_text)
        out: list[Expectation] = []
        for k, lt in enumerate(letters):
            nxt = letters[k + 1] if k + 1 < len(letters) else None
            out.extend(self._noon_rules(lt, nxt))
            ghunnah = self._ghunnah(lt)
            if ghunnah:
                out.append(ghunnah)
            madd = self._madd(lt, letters[k - 1] if k > 0 else None)
            if madd:
                out.append(madd)
        return out

    # ----- noon-sakinah / tanween family (Class A) ------------------------- #
    def _noon_rules(self, lt: P.Letter, nxt: P.Letter | None) -> list[Expectation]:
        is_noon_sakin = lt.char == P.NOON and (lt.has_sukoon or lt.is_bare)
        tanween = lt.tanween
        if not (is_noon_sakin or tanween) or nxt is None:
            return []

        f = nxt.char
        base = "noon-sakinah" if is_noon_sakin else "tanween"

        if f in P.IQLAB_TRIGGER:
            return [Expectation("Iqlab", "A", lt.char, lt.index, f,
                                f"{base} before ب -> pronounced as م (meem) with ghunnah",
                                with_ghunnah=True)]
        if f in P.YARMALOON_IDGHAM:
            wg = f in P.IDGHAM_WITH_GHUNNAH
            kind = "with ghunnah" if wg else "without ghunnah"
            return [Expectation("Idgham", "A", lt.char, lt.index, f,
                                f"{base} before '{f}' -> assimilates ({kind})",
                                with_ghunnah=wg)]
        if f in P.IKHFAA_15:
            return [Expectation("Ikhfaa", "A", lt.char, lt.index, f,
                                f"{base} before '{f}' -> hidden with nasalization",
                                with_ghunnah=True)]
        if f in P.THROAT_IZHAR:
            return [Expectation("Izhar", "A", lt.char, lt.index, f,
                                f"{base} before throat letter '{f}' -> pronounced clearly",
                                with_ghunnah=False)]
        return []

    # ----- ghunnah on shadda (Class B) ------------------------------------- #
    def _ghunnah(self, lt: P.Letter) -> Expectation | None:
        if lt.char in (P.NOON, P.MEEM) and lt.has_shadda:
            return Expectation("Ghunnah", "B", lt.char, lt.index, None,
                               f"2-beat nasalization on {lt.char} مشددة", with_ghunnah=True)
        return None

    # ----- madd letters (Class B) ------------------------------------------ #
    def _madd(self, lt: P.Letter, prev: P.Letter | None) -> Expectation | None:
        # A madd letter prolongs the preceding short vowel:
        #   ا after fatha, و after damma, ي after kasra; dagger-alif always.
        if lt.char == P.DAGGER_ALIF or P.MADDAH in lt.marks:
            return Expectation("Madd", "B", lt.char, lt.index, None,
                               "vowel prolongation (madd)")
        if lt.char in {"ا", "و", "ي"} and lt.is_bare and prev is not None:
            harmonic = {"ا": P.FATHA, "و": P.DAMMA, "ي": P.KASRA}[lt.char]
            if harmonic in prev.marks:
                return Expectation("Madd", "B", lt.char, lt.index, None,
                                   "vowel prolongation (madd)")
        return None


def expected_positions(verse_text: str) -> list[Expectation]:
    """Convenience wrapper."""
    return TajweedEngine().expected(verse_text)
