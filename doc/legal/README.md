# Legal drafts (Phase 5.2, commit 4)

**Drafts, not published, not legal advice.** Written from what the code actually stores and
where (checked against `supabase/migrations/`, `server/`, the app's storage and
`privacy_screen.dart` on 20 November 2026), to be reviewed by the owner, then by a
professional before Phase 6 publishes them as pages linked in the app (plan, Phase 6 step 2).

| File | What |
|---|---|
| `privacy-policy.md` | Privacy policy (GDPR information, art. 13) |
| `legal-notice.md` | Legal notice (*mentions légales*, French LCEN art. 6 III) |

**Placeholders** are written `[[LIKE THIS]]`: the publisher's identity, address and contact,
the hosts' regions, the app's final name and domain. Search for `[[` before publishing.

**Questions for the professional review** (decisions the drafts cannot make):

1. **Language.** The app is in English; a site published from France for a French audience
   is expected to carry its legal notice in French (loi Toubon applies to consumer-facing
   information). Publish both languages?
2. **Minors.** The game is for teens and adults. The drafts rely on *performance of the
   service* (art. 6(1)(b)) and *legitimate interest* (art. 6(1)(f)), not consent — so the
   French age of digital consent (15, art. 8 GDPR / loi Informatique et Libertés art. 45) is
   not triggered directly. Is a minimum age, or parental information for under-15s, still
   advisable?
3. **Transfers outside the EU.** Render (the server) and Cloudflare (the site) are US
   companies; the Supabase project's region is `[[REGION]]`. The drafts point to the EU–US
   Data Privacy Framework and standard contractual clauses — to confirm against each
   provider's current DPA.
4. **Publisher as a private individual.** LCEN allows a non-professional publisher to keep
   their name and address off the site if the host has them: does that suit the owner?
5. **Beta data.** Answer data is used to calibrate levels (legitimate interest). Is the
   wording enough, given testers are invited?

**Known gap in the app** (to fix with Phase 6's pages, not before — the beta-safety rule and
"nothing players can see" in Phase 5.2): the in-app notice (`privacy_screen.dart`) does not
yet say that the **input device** (on-screen keypad or keyboard) and the **app version** are
stored with each game, nor that games may be **flagged for implausible timing**. The policy
below does.
