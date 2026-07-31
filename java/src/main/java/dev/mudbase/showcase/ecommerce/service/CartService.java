package dev.mudbase.showcase.ecommerce.service;

import dev.mudbase.showcase.ecommerce.auth.AuthSession;
import dev.mudbase.showcase.ecommerce.auth.GuestCartHolder;
import dev.mudbase.showcase.ecommerce.config.MudbaseProperties;
import dev.mudbase.showcase.ecommerce.domain.Cart;
import dev.mudbase.showcase.ecommerce.domain.CartItem;
import dev.mudbase.showcase.ecommerce.mudbase.JsonFields;
import dev.mudbase.showcase.ecommerce.mudbase.MudbaseDataClient;
import jakarta.servlet.http.HttpSession;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * Reads and writes the shopping cart: a plain HttpSession-held list before sign-in (Mudbase's
 * `customer`-role-only ownership condition on the `carts` collection denies an anonymous-guest
 * session entirely - see GuestCartHolder), and the real `carts` document, read-then-create-or-update
 * since there is no native upsert, once the shopper is signed in as a customer.
 */
@Service
public class CartService {

  private final MudbaseDataClient dataClient;
  private final MudbaseProperties properties;

  public CartService(MudbaseDataClient dataClient, MudbaseProperties properties) {
    this.dataClient = dataClient;
    this.properties = properties;
  }

  private boolean usesServerCart(AuthSession auth) {
    return auth != null && auth.isSignedIn() && auth.isCustomer();
  }

  private Optional<Cart> findServerCart(AuthSession auth) {
    List<Map<String, Object>> docs =
        dataClient.list(
            auth.getToken(),
            properties.getCartsCollectionId(),
            Map.of("userId", auth.getUserId()),
            "-createdAt",
            1,
            1);
    return docs.isEmpty() ? Optional.empty() : Optional.of(Cart.fromDocument(docs.get(0)));
  }

  public List<CartItem> getItems(HttpSession session, AuthSession auth) {
    if (usesServerCart(auth)) {
      return findServerCart(auth).map(Cart::getItems).orElseGet(List::of);
    }
    return GuestCartHolder.get(session);
  }

  public long getSubtotalCents(List<CartItem> items) {
    return items.stream().mapToLong(CartItem::getLineTotalCents).sum();
  }

  public void addItem(HttpSession session, AuthSession auth, CartItem item, int quantity) {
    List<CartItem> current = new ArrayList<>(getItems(session, auth));
    int existingIndex = indexOf(current, item.productId());
    if (existingIndex >= 0) {
      CartItem existing = current.get(existingIndex);
      current.set(existingIndex, existing.withQuantity(existing.quantity() + quantity));
    } else {
      current.add(item.withQuantity(quantity));
    }
    persist(session, auth, current);
  }

  public void updateQuantity(HttpSession session, AuthSession auth, String productId, int quantity) {
    List<CartItem> current = new ArrayList<>(getItems(session, auth));
    if (quantity <= 0) {
      current.removeIf(i -> i.productId().equals(productId));
    } else {
      int index = indexOf(current, productId);
      if (index >= 0) {
        current.set(index, current.get(index).withQuantity(quantity));
      }
    }
    persist(session, auth, current);
  }

  public void removeItem(HttpSession session, AuthSession auth, String productId) {
    List<CartItem> current = new ArrayList<>(getItems(session, auth));
    current.removeIf(i -> i.productId().equals(productId));
    persist(session, auth, current);
  }

  public void clear(HttpSession session, AuthSession auth) {
    persist(session, auth, List.of());
  }

  private int indexOf(List<CartItem> items, String productId) {
    for (int i = 0; i < items.size(); i++) {
      if (items.get(i).productId().equals(productId)) {
        return i;
      }
    }
    return -1;
  }

  private void persist(HttpSession session, AuthSession auth, List<CartItem> items) {
    if (!usesServerCart(auth)) {
      GuestCartHolder.set(session, items);
      return;
    }
    // Re-fetch right before deciding create-vs-update rather than trusting any caller-held
    // snapshot, so a cart created moments earlier by migrateGuestCartToServer() in the same
    // request sequence is never silently overwritten by a second, duplicate cart document.
    Optional<Cart> existing = findServerCart(auth);
    Map<String, Object> body = Map.of("itemsJson", JsonFields.stringify(items));
    if (existing.isPresent()) {
      dataClient.update(auth.getToken(), properties.getCartsCollectionId(), existing.get().getId(), body);
    } else {
      Map<String, Object> createBody = new LinkedHashMap<>(body);
      createBody.put("userId", auth.getUserId());
      dataClient.create(auth.getToken(), properties.getCartsCollectionId(), createBody);
    }
  }

  /** Called once, right after a guest completes registration or signs in at checkout. */
  public void migrateGuestCartToServer(HttpSession session, AuthSession auth) {
    List<CartItem> guestItems = GuestCartHolder.get(session);
    if (guestItems.isEmpty()) {
      return;
    }
    Optional<Cart> existing = findServerCart(auth);
    if (existing.isEmpty()) {
      dataClient.create(
          auth.getToken(),
          properties.getCartsCollectionId(),
          Map.of("userId", auth.getUserId(), "itemsJson", JsonFields.stringify(guestItems)));
      GuestCartHolder.clear(session);
      return;
    }
    List<CartItem> merged = new ArrayList<>(existing.get().getItems());
    for (CartItem guestItem : guestItems) {
      int index = indexOf(merged, guestItem.productId());
      if (index >= 0) {
        CartItem current = merged.get(index);
        merged.set(index, current.withQuantity(current.quantity() + guestItem.quantity()));
      } else {
        merged.add(guestItem);
      }
    }
    dataClient.update(
        auth.getToken(),
        properties.getCartsCollectionId(),
        existing.get().getId(),
        Map.of("itemsJson", JsonFields.stringify(merged)));
    GuestCartHolder.clear(session);
  }
}
