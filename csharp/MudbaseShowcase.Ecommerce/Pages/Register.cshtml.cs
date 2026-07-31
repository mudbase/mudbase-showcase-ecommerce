using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages;

/// <summary>
/// Self-signup is always "customer" — role is never taken from user input. Sellers are
/// provisioned out-of-band (see README "Provisioning"), matching web/src/components/auth/RegisterForm.tsx,
/// which hardcodes role: "customer" and never exposes a role picker.
/// </summary>
public sealed class RegisterModel : PageModel
{
    private readonly MudbaseAuthService _authService;
    private readonly CartService _cart;
    private readonly MudbaseSessionAccessor _session;

    public RegisterModel(MudbaseAuthService authService, CartService cart, MudbaseSessionAccessor session)
    {
        _authService = authService;
        _cart = cart;
        _session = session;
    }

    [BindProperty]
    public RegisterInput Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!Input.AgreedToTerms)
        {
            // Must be the fully-qualified "Input.AgreedToTerms" key, matching the [BindProperty]
            // prefix — plain nameof(Input.AgreedToTerms) resolves to just "AgreedToTerms" and
            // silently fails to line up with asp-validation-for="Input.AgreedToTerms" in the view.
            ModelState.AddModelError($"{nameof(Input)}.{nameof(Input.AgreedToTerms)}", "You must agree to the Terms of Service and Privacy Policy.");
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        AuthOutcome outcome = await _authService.RegisterCustomerAsync(
            Input.Email, Input.Password, Input.FirstName, Input.LastName, Input.AgreedToTerms, cancellationToken);

        if (!outcome.Succeeded)
        {
            ErrorMessage = outcome.ErrorMessage ?? "Registration failed";
            return Page();
        }

        MudbaseSessionUser? user = _session.CurrentUser;
        if (user is not null)
        {
            await _cart.MigrateGuestCartToServerAsync(user.Id, cancellationToken);
        }

        if (!string.IsNullOrWhiteSpace(ReturnUrl) && Url.IsLocalUrl(ReturnUrl))
        {
            return LocalRedirect(ReturnUrl);
        }

        return RedirectToPage("/Index");
    }

    public sealed class RegisterInput
    {
        [Required(ErrorMessage = "First name is required")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Last name is required")]
        public string LastName { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email is required"), EmailAddress(ErrorMessage = "Enter a valid email address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        [MinLength(8, ErrorMessage = "Password must be at least 8 characters")]
        public string Password { get; set; } = string.Empty;

        public bool AgreedToTerms { get; set; }
    }
}
