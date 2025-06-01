# RSCSS Commandments
1. **Think in components, not `<div>` soup**
   Every top-level piece of UI is a *component* with a **two-word dashed** class name.
   ```html
   <article class="comment-box">…</article>
   ```
2. **Elements: single word + direct child**
   Use one bare word for each child and the `>` combinator so styles don't leak.
   ```css
   .comment-box > .title { … }
   ```
3. **Variants: add a leading dash**
   ```css
   .comment-box {
     &.-featured { … }          /* component variant */
     & > .title.-small { … }    /* element variant */
   }
   ```
4. **One component per file**
   File: `app/assets/stylesheets/comment-box.css`.
5. **Never nest more than one level**
   Two hops max: `.outer > .inner`. Deeper = maintenance nightmare.
6. **Nested components stay independent**
   Give the inner thing its own dashed class (`.avatar-card` inside `.comment-box`).
7. **Compose variants, don't concatenate**
   Need *big* **and** *warning*? `class=".-big -warning"` (two classes), not `.-big-warning`.
8. **Helpers/utilities: generic, single-purpose**
   `.is-hidden`, `.u-text-center`, `.js-hook`—one job each, no style bleed.
9. **Describe purpose, not paint color**
   `.alert` or `.-error` > `.red-text`. Designers will thank you.
10. **When in doubt, reread this list**
    TL;DR: **Component → Element → Dash variant → Shallow nesting**.
