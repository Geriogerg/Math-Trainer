# Legal pages

Since Phase 6c commit 2 the **privacy policy** and the **legal notice** are in-app pages, in
English and French: `app/lib/presentation/strings/legal/legal_texts.dart` (one class per
language, so a missing translation does not compile), shown by
`app/lib/presentation/screens/legal_screen.dart` and linked from the beta gate, Profile and
Save your progress. They replace the Phase 5.2 drafts that stood here (removed; in git
history before commit 2 of Phase 6c).

**Not final.** The owner's details are placeholders, shown highlighted under a "Draft" banner
until given in `legal_details.dart` (`LegalDetails.given`, per language): publisher,
contact email, director of publication, Cloudflare's address and telephone, the Supabase
project's region, the version's date. Then the pages go to a professional review (plan
section 6.6) before the switch-on.

**Questions for the professional review** (what the pages cannot decide):

1. **Publisher as a private individual.** LCEN art. 6 III-2 lets a non-professional
   publisher keep their name and address off the site if the host has them: does the
   notice's wording suit, and which host (Cloudflare, which serves the site)?
2. **Minimum age.** 15, declared at account creation ("I am 15 or older", kept in the
   account's metadata). The bases are contract (art. 6(1)(b)) and legitimate interest
   (6(1)(f)), not consent: is the declaration enough, and is anything owed to guests (no
   account, no email) under 15?
3. **Transfers outside the EU.** Render (the server, United States) and Cloudflare are US
   companies; Supabase's region is the owner's to give. The pages point to the EU–US Data
   Privacy Framework or standard contractual clauses — to confirm against each provider's
   current terms.
4. **Turnstile and error reports** (Phase 6c commits 3 and 5): Cloudflare's bot check and the
   game's own error reports — described as the code does them; the wording to confirm.
5. **Retention of hosting logs**: the pages do not give durations for the providers' own
   logs.
