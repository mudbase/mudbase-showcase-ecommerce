package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-ecommerce/go/internal/models"
)

// Catalog implements every operation the storefront needs against the `products` collection.
type Catalog struct {
	client       *mbase.Client
	collectionID string
}

// NewCatalog builds a Catalog bound to the given products collection ID.
func NewCatalog(client *mbase.Client, productsCollectionID string) *Catalog {
	return &Catalog{client: client, collectionID: productsCollectionID}
}

const catalogPageLimit = 60
const sellerCatalogPageLimit = 100

// ListActive returns active products, optionally narrowed to one category, newest first -
// mirrors web/src/components/catalog/ProductGrid.tsx's `{ isActive: true, category }` filter.
func (c *Catalog) ListActive(ctx context.Context, token, category string) ([]models.Product, error) {
	filter := map[string]interface{}{"isActive": true}
	if category != "" {
		filter["category"] = category
	}
	result, err := mbase.List[models.Product](ctx, c.client, token, c.collectionID, mbase.ListParams{
		Filter: filter,
		Sort:   "-createdAt",
		Limit:  catalogPageLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing active products: %w", err)
	}
	return result.Data, nil
}

// ListAllForSeller returns every product regardless of active state, for the seller product
// table - mirrors web/src/components/seller/ProductTable.tsx (no isActive filter).
func (c *Catalog) ListAllForSeller(ctx context.Context, token string) ([]models.Product, error) {
	result, err := mbase.List[models.Product](ctx, c.client, token, c.collectionID, mbase.ListParams{
		Sort:  "-createdAt",
		Limit: sellerCatalogPageLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing all products: %w", err)
	}
	return result.Data, nil
}

// BySlug looks up a single product by its public slug, returning ok=false when none matches.
func (c *Catalog) BySlug(ctx context.Context, token, slug string) (models.Product, bool, error) {
	result, err := mbase.List[models.Product](ctx, c.client, token, c.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"slug": slug},
		Limit:  1,
	})
	if err != nil {
		return models.Product{}, false, fmt.Errorf("store: looking up product by slug %q: %w", slug, err)
	}
	if len(result.Data) == 0 {
		return models.Product{}, false, nil
	}
	return result.Data[0], true, nil
}

// ByID fetches a single product by its Mudbase document ID.
func (c *Catalog) ByID(ctx context.Context, token, id string) (models.Product, error) {
	product, err := mbase.Get[models.Product](ctx, c.client, token, c.collectionID, id)
	if err != nil {
		return models.Product{}, fmt.Errorf("store: fetching product %s: %w", id, err)
	}
	return product, nil
}

// ProductInput is the seller-editable subset of a product, decoupled from the Mudbase wire shape
// so handlers can build it directly from a validated form.
type ProductInput struct {
	Name                string
	Description         string
	PriceCents          int64
	CompareAtPriceCents *int64
	Currency            string
	ImageURL            string
	Category            string
	Stock               int64
	IsActive            bool
	GalleryURLs         []string
}

func (in ProductInput) toBody() (map[string]interface{}, error) {
	galleryJSON, err := models.StringifyJSONField(in.GalleryURLs)
	if err != nil {
		return nil, fmt.Errorf("store: encoding gallery photos: %w", err)
	}
	body := map[string]interface{}{
		"name":        in.Name,
		"description": in.Description,
		"priceCents":  in.PriceCents,
		"currency":    in.Currency,
		"imageUrl":    in.ImageURL,
		"galleryJson": galleryJSON,
		"category":    in.Category,
		"stock":       in.Stock,
		"isActive":    in.IsActive,
	}
	// Omitted entirely (not sent as null) when absent, matching the reference web app's own
	// behavior: react-hook-form leaves compareAtPriceCents undefined for "no discount", and a
	// PATCH-style update only ever touches fields explicitly present in the request body.
	if in.CompareAtPriceCents != nil {
		body["compareAtPriceCents"] = *in.CompareAtPriceCents
	}
	return body, nil
}

// Create inserts a new product owned by sellerID, generating a fresh unique-enough slug.
func (c *Catalog) Create(ctx context.Context, token, sellerID string, in ProductInput) (models.Product, error) {
	slug, err := newProductSlug(in.Name)
	if err != nil {
		return models.Product{}, fmt.Errorf("store: generating product slug: %w", err)
	}
	body, err := in.toBody()
	if err != nil {
		return models.Product{}, err
	}
	body["slug"] = slug
	body["sellerId"] = sellerID

	product, err := mbase.Create[models.Product](ctx, c.client, token, c.collectionID, body)
	if err != nil {
		return models.Product{}, fmt.Errorf("store: creating product: %w", err)
	}
	return product, nil
}

// Update patches an existing product's editable fields (slug and sellerId are immutable after
// creation, matching web/src/app/seller/products/[id]/edit/page.tsx which never re-sends them).
func (c *Catalog) Update(ctx context.Context, token, id string, in ProductInput) (models.Product, error) {
	body, err := in.toBody()
	if err != nil {
		return models.Product{}, err
	}
	product, err := mbase.Update[models.Product](ctx, c.client, token, c.collectionID, id, body)
	if err != nil {
		return models.Product{}, fmt.Errorf("store: updating product %s: %w", id, err)
	}
	return product, nil
}

// Delete removes a product from the catalog.
func (c *Catalog) Delete(ctx context.Context, token, id string) error {
	if err := mbase.Delete(ctx, c.client, token, c.collectionID, id); err != nil {
		return fmt.Errorf("store: deleting product %s: %w", id, err)
	}
	return nil
}
