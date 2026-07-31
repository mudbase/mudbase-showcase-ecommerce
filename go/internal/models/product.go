package models

// Product mirrors the `products` Mudbase collection schema (see web/plan/build-plan.md). Every
// field maps 1:1 to a collection field; galleryJson is the JSON-string-array workaround documented
// in jsonfield.go for the extra product photos shown in the gallery carousel.
type Product struct {
	ID                  string `json:"_id"`
	CreatedAt           string `json:"createdAt"`
	UpdatedAt           string `json:"updatedAt"`
	Name                string `json:"name"`
	Slug                string `json:"slug"`
	Description         string `json:"description"`
	PriceCents          int64  `json:"priceCents"`
	CompareAtPriceCents *int64 `json:"compareAtPriceCents,omitempty"`
	Currency            string `json:"currency"`
	ImageURL            string `json:"imageUrl"`
	GalleryJSON         string `json:"galleryJson"`
	Category            string `json:"category"`
	Stock               int64  `json:"stock"`
	IsActive            bool   `json:"isActive"`
	SellerID            string `json:"sellerId"`
}

// Gallery returns every image URL for this product (main image first, then the JSON-encoded
// extra gallery photos), skipping empty values.
func (p Product) Gallery() []string {
	extra := ParseJSONField[[]string](p.GalleryJSON, nil)
	images := make([]string, 0, len(extra)+1)
	if p.ImageURL != "" {
		images = append(images, p.ImageURL)
	}
	for _, url := range extra {
		if url != "" {
			images = append(images, url)
		}
	}
	return images
}

// DiscountPercent returns the whole-number percent-off versus CompareAtPriceCents, or nil when
// there is no active discount (mirrors web/src/lib/utils.ts discountPercent()).
func (p Product) DiscountPercent() *int {
	if p.CompareAtPriceCents == nil || *p.CompareAtPriceCents <= p.PriceCents {
		return nil
	}
	percent := int((1.0 - float64(p.PriceCents)/float64(*p.CompareAtPriceCents)) * 100)
	return &percent
}

// OutOfStock reports whether the product has zero or negative stock.
func (p Product) OutOfStock() bool {
	return p.Stock <= 0
}
