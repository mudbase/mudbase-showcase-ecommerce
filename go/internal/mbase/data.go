package mbase

import (
	"context"
	"encoding/json"
	"fmt"
)

// ListParams mirrors the query options the real ListData endpoint accepts (see
// mudbase-sdk/go/docs/DataApi.md): Mongo-style filter (JSON-encoded), sort string, and pagination.
type ListParams struct {
	Filter map[string]interface{}
	Sort   string
	Page   int32
	Limit  int32
}

// ListResult is a typed, decoded page of collection documents plus pagination metadata.
type ListResult[T any] struct {
	Data       []T
	Page       int32
	Limit      int32
	Total      int32
	TotalPages int32
}

// decodeInto re-marshals a document (a map[string]interface{} from DataResponse, or a
// DataListResponseDataInner whose own MarshalJSON merges _id/createdAt/updatedAt with its
// AdditionalProperties map) into a concrete Go struct. This round-trip is the simplest correct way
// to turn Mudbase's schemaless collection documents into this app's typed Product/Order/Cart
// structs without hand-writing a type switch over map[string]interface{} for every field.
func decodeInto[T any](raw interface{}) (T, error) {
	var out T
	b, err := json.Marshal(raw)
	if err != nil {
		return out, fmt.Errorf("mbase: encoding document for decode: %w", err)
	}
	if err := json.Unmarshal(b, &out); err != nil {
		return out, fmt.Errorf("mbase: decoding document into %T: %w", out, err)
	}
	return out, nil
}

// List fetches a page of documents from collectionID, decoded into T.
func List[T any](ctx context.Context, c *Client, token, collectionID string, params ListParams) (ListResult[T], error) {
	req := c.SDK.DataAPI.ListData(authedContext(ctx, token), c.cfg.ProjectID, collectionID)
	if params.Page > 0 {
		req = req.Page(params.Page)
	}
	if params.Limit > 0 {
		req = req.Limit(params.Limit)
	}
	if params.Sort != "" {
		req = req.Sort(params.Sort)
	}
	if len(params.Filter) > 0 {
		filterJSON, err := json.Marshal(params.Filter)
		if err != nil {
			return ListResult[T]{}, fmt.Errorf("mbase: encoding filter for %s: %w", collectionID, err)
		}
		req = req.Filter(string(filterJSON))
	}

	resp, _, err := req.Execute()
	if err != nil {
		return ListResult[T]{}, wrapAPIError(fmt.Sprintf("mbase: listing %s", collectionID), err)
	}

	pagination := resp.GetPagination()
	result := ListResult[T]{
		Page:       pagination.GetPage(),
		Limit:      pagination.GetLimit(),
		Total:      pagination.GetTotal(),
		TotalPages: pagination.GetTotalPages(),
	}
	for _, item := range resp.GetData() {
		decoded, err := decodeInto[T](item)
		if err != nil {
			return ListResult[T]{}, err
		}
		result.Data = append(result.Data, decoded)
	}
	return result, nil
}

// Get fetches a single document by ID, decoded into T.
func Get[T any](ctx context.Context, c *Client, token, collectionID, documentID string) (T, error) {
	var zero T
	resp, _, err := c.SDK.DataAPI.GetData(authedContext(ctx, token), c.cfg.ProjectID, collectionID, documentID).Execute()
	if err != nil {
		return zero, wrapAPIError(fmt.Sprintf("mbase: fetching %s/%s", collectionID, documentID), err)
	}
	return decodeInto[T](resp.GetData())
}

// Create inserts a new document into collectionID and returns the created, decoded document.
func Create[T any](ctx context.Context, c *Client, token, collectionID string, body map[string]interface{}) (T, error) {
	var zero T
	resp, _, err := c.SDK.DataAPI.CreateData(authedContext(ctx, token), c.cfg.ProjectID, collectionID).Body(body).Execute()
	if err != nil {
		return zero, wrapAPIError(fmt.Sprintf("mbase: creating %s document", collectionID), err)
	}
	return decodeInto[T](resp.GetData())
}

// Update patches an existing document and returns the updated, decoded document.
func Update[T any](ctx context.Context, c *Client, token, collectionID, documentID string, body map[string]interface{}) (T, error) {
	var zero T
	resp, _, err := c.SDK.DataAPI.UpdateData(authedContext(ctx, token), c.cfg.ProjectID, collectionID, documentID).Body(body).Execute()
	if err != nil {
		return zero, wrapAPIError(fmt.Sprintf("mbase: updating %s/%s", collectionID, documentID), err)
	}
	return decodeInto[T](resp.GetData())
}

// Delete removes a document by ID.
func Delete(ctx context.Context, c *Client, token, collectionID, documentID string) error {
	_, _, err := c.SDK.DataAPI.DeleteData(authedContext(ctx, token), c.cfg.ProjectID, collectionID, documentID).Execute()
	if err != nil {
		return wrapAPIError(fmt.Sprintf("mbase: deleting %s/%s", collectionID, documentID), err)
	}
	return nil
}
