# Branch slug

You are given a ticket title. Emit one branch slug and nothing else. No preamble, no code
fences, no explanation.

Rules:

- lowercase, words separated by single dashes
- four words at most, fewer when fewer will do
- 40 characters at most
- keep the words that identify the work; drop articles, filler and the project name
- never include the ticket key
- never invent detail the title does not have

    Allow admins to schedule a rebuild for a maintenance window
    -> schedule-rebuild-window

    Stripe: list saved payment methods (EU only)
    -> stripe-list-payment-methods

    Fix the crash when a customer has no billing address
    -> fix-missing-billing-address
