using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MudbaseShowcase.Ecommerce.Services;

namespace MudbaseShowcase.Ecommerce.Pages;

public sealed class LogoutModel : PageModel
{
    private readonly MudbaseAuthService _authService;

    public LogoutModel(MudbaseAuthService authService)
    {
        _authService = authService;
    }

    public IActionResult OnGet() => RedirectToPage("/Index");

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        await _authService.LogoutAsync(cancellationToken);
        return RedirectToPage("/Index");
    }
}
