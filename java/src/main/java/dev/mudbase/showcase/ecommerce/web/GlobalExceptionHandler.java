package dev.mudbase.showcase.ecommerce.web;

import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseApiException;
import dev.mudbase.showcase.ecommerce.support.ViewModelHelper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * Every unhandled Mudbase call failure lands here instead of a raw stack trace. A 401 (stale or
 * expired session JWT - this app does not implement refresh-token rotation, matching the
 * reference web app's own scope) clears the session and bounces to /login; everything else
 * renders a plain error page with the real Mudbase-provided message.
 */
@ControllerAdvice
public class GlobalExceptionHandler {

  private final SessionAuthService sessionAuthService;
  private final ViewModelHelper viewModelHelper;

  public GlobalExceptionHandler(SessionAuthService sessionAuthService, ViewModelHelper viewModelHelper) {
    this.sessionAuthService = sessionAuthService;
    this.viewModelHelper = viewModelHelper;
  }

  @ExceptionHandler(MudbaseApiException.class)
  public ModelAndView handleMudbaseError(
      MudbaseApiException exception, HttpServletRequest request, Model model, RedirectAttributes redirectAttributes) {
    if (exception.isUnauthorized()) {
      sessionAuthService.logout(request.getSession());
      redirectAttributes.addFlashAttribute("errorMessage", "Your session expired - please sign in again.");
      return new ModelAndView("redirect:/login");
    }
    viewModelHelper.addLayoutAttributes(model, request.getSession());
    model.addAttribute("errorMessage", exception.getMessage());
    model.addAttribute("statusCode", exception.getStatusCode());
    ModelAndView mav = new ModelAndView("error");
    mav.setStatus(HttpStatus.valueOf(exception.getStatusCode() >= 400 ? exception.getStatusCode() : 500));
    return mav;
  }
}
