package dev.mudbase.showcase.ecommerce.mudbase;

import dev.mudbase.showcase.ecommerce.config.MudbaseClientFactory;
import dev.mudbase.sdk.ApiException;
import dev.mudbase.sdk.api.DataApi;
import dev.mudbase.sdk.model.DataListResponse;
import dev.mudbase.sdk.model.DataResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Thin, typed-enough wrapper over the generated {@link DataApi} for this app's three collections.
 * Every collection call needs the caller's own bearer token (customer/seller/anonymous-guest) so
 * Mudbase's own collection permissions - ownership conditions on orders/carts, role-gated CRUD on
 * products - are the real security boundary, exactly as documented in the reference web app.
 */
@Component
public class MudbaseDataClient {

  private final MudbaseClientFactory clientFactory;

  public MudbaseDataClient(MudbaseClientFactory clientFactory) {
    this.clientFactory = clientFactory;
  }

  public List<Map<String, Object>> list(
      String bearerToken, String collectionId, Map<String, Object> filter, String sort, int page, int limit) {
    DataApi dataApi = clientFactory.dataApi(bearerToken);
    String filterJson = filter == null || filter.isEmpty() ? null : JsonFields.stringify(filter);
    try {
      DataListResponse response =
          dataApi.listData(clientFactory.projectId(), collectionId, page, limit, sort, filterJson);
      List<Map<String, Object>> results = new ArrayList<>();
      if (response.getData() != null) {
        for (var item : response.getData()) {
          results.add(DocumentMapper.fromListItem(item));
        }
      }
      return results;
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  public Map<String, Object> get(String bearerToken, String collectionId, String documentId) {
    DataApi dataApi = clientFactory.dataApi(bearerToken);
    try {
      DataResponse response = dataApi.getData(clientFactory.projectId(), collectionId, documentId);
      return DocumentMapper.asMap(response.getData());
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  public Map<String, Object> create(String bearerToken, String collectionId, Map<String, Object> body) {
    DataApi dataApi = clientFactory.dataApi(bearerToken);
    try {
      DataResponse response = dataApi.createData(clientFactory.projectId(), collectionId, body);
      return DocumentMapper.asMap(response.getData());
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  public Map<String, Object> update(
      String bearerToken, String collectionId, String documentId, Map<String, Object> body) {
    DataApi dataApi = clientFactory.dataApi(bearerToken);
    try {
      DataResponse response = dataApi.updateData(clientFactory.projectId(), collectionId, documentId, body);
      return DocumentMapper.asMap(response.getData());
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }

  public void delete(String bearerToken, String collectionId, String documentId) {
    DataApi dataApi = clientFactory.dataApi(bearerToken);
    try {
      dataApi.deleteData(clientFactory.projectId(), collectionId, documentId);
    } catch (ApiException e) {
      throw MudbaseApiException.from(e);
    }
  }
}
