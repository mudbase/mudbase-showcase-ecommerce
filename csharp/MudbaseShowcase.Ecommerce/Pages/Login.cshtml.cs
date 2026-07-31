using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Ecommerce.Models;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages;

public sealed class LoginModel : PageModel
{
    private readonly MudbaseAuthService _authService;

    public LoginModel(MudbaseAuthService authService)
    {
        _authService = authService;
    }

    [BindProperty]
    public LoginInput Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }

    /// <summary>Where to send the shopper after a successful sign-in — the checkout page passes its own URL here so login doesn't bounce them home mid-checkout.</summary>
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        AuthOutcome outcome = await _authService.LoginAsync(Input.Email, Input.Password, cancellationToken);
        if (!outcome.Succeeded)
        {
            ErrorMessage = outcome.ErrorMessage ?? "Login failed";
            return Page();
        }

        if (!string.IsNullOrWhiteSpace(ReturnUrl) && Url.IsLocalUrl(ReturnUrl))
        {
            return LocalRedirect(ReturnUrl);
        }

        MudbaseSessionUser? user = HttpContext.RequestServices.GetRequiredService<MudbaseSessionAccessor>().CurrentUser;
        return user is { IsSeller: true } ? RedirectToPage("/Seller/Index") : RedirectToPage("/Index");
    }

    public sealed class LoginInput
    {
        [Required(ErrorMessage = "Email is required"), EmailAddress(ErrorMessage = "Enter a valid email address")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required")]
        public string Password { get; set; } = string.Empty;
    }
}
