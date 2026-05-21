# Browse Hero Design

**Date:** 2026-05-14

**Problem**

The top of the public browse page feels visually unstructured. Brand assets appear oversized or loosely placed, the welcome banner reads as a generic block rather than a composed header, and the app bar branding competes with the page body instead of supporting it.

**Approved Direction**

Replace the current welcome banner on the public browse page with a balanced editorial hero. The hero should present a restrained brand treatment, a stronger browse/discovery message, and clear sign-in/create-account actions in a single composed unit. The supporting concept artwork should remain, but inside a constrained framed region so it reads as an accent instead of a floating large image.

**Layout**

- On desktop and wide tablet widths, render the hero as a two-column card.
- Left column: eyebrow brand label, browse headline, supporting copy, primary and secondary auth actions.
- Right column: framed concept image with fixed max height, rounded corners, and controlled fit.
- On smaller widths, collapse to a single column with text/actions first and the visual second.
- Keep the quest list visible near the fold by limiting hero height and padding.

**Branding Adjustments**

- Reduce the visual weight of the shared app-bar branding.
- Slightly shrink the logo height and tighten spacing in the branding widget.
- Keep the app bar as navigation chrome while the hero becomes the main visual entry point.

**Non-Goals**

- No routing changes.
- No auth flow changes.
- No filtering logic changes.
- No quest list behavior changes.
- No broader design-system rewrite.

**Validation**

- Run focused Flutter analysis on the touched UI files.
- Run Flutter tests to guard against layout-related regressions.
- Rebuild web output and redeploy the Firebase preview channel for visual review.