package dev.mudbase.showcase.ecommerce.config;

import dev.mudbase.showcase.ecommerce.auth.RequireSellerInterceptor;
import dev.mudbase.showcase.ecommerce.auth.RequireSignInInterceptor;
import dev.mudbase.showcase.ecommerce.auth.SessionAuthService;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

  private final SessionAuthService sessionAuthService;

  public WebMvcConfig(SessionAuthService sessionAuthService) {
    this.sessionAuthService = sessionAuthService;
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(new RequireSignInInterceptor(sessionAuthService)).addPathPatterns("/orders/**");
    registry.addInterceptor(new RequireSellerInterceptor(sessionAuthService)).addPathPatterns("/seller/**");
  }
}
