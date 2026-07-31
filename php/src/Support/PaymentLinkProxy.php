<?php

declare(strict_types=1);

namespace App\Support;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;

/**
 * Creating a Mudbase Payment Link requires a live org owner/admin bearer session — there is no
 * API-key path for `POST /api/orgs/:orgId/payment-links`. Rather than every per-language
 * reimplementation of this storefront independently holding and rotating the same single-use
 * merchant refresh token (a real race condition the moment two of these run concurrently), this
 * app delegates payment-link creation to the already-deployed reference Next.js app's Route
 * Handler, which owns that merchant session server-side (see its src/lib/mudbase-server.ts).
 *
 * The public payment-link status read (`GET /api/payment-links/:token`) needs no auth at all, so
 * that one goes straight to Mudbase — see fetchStatus() below.
 */
final class PaymentLinkProxy
{
    public function __construct(
        private readonly string $proxyUrl,
        private readonly string $mudbaseUrl,
    ) {
    }

    /**
     * @return array{ok: true, link: array<string, mixed>}|array{ok: false, reason: string, message: string}
     */
    public function createForOrder(string $orderId, string $amount, string $currency, string $network, string $redirectUrl): array
    {
        $client = new GuzzleClient(['timeout' => 15]);

        try {
            $response = $client->post($this->proxyUrl, [
                'json' => [
                    'orderId' => $orderId,
                    'amount' => $amount,
                    'currency' => $currency,
                    'network' => $network,
                    'redirectUrl' => $redirectUrl,
                ],
                'http_errors' => false,
            ]);
        } catch (GuzzleException $e) {
            return ['ok' => false, 'reason' => 'unreachable', 'message' => "Couldn't reach the payment service: {$e->getMessage()}"];
        }

        $status = $response->getStatusCode();
        $body = json_decode((string) $response->getBody(), true);
        $body = is_array($body) ? $body : [];

        if ($status === 403) {
            $message = is_string($body['error'] ?? null)
                ? $body['error']
                : "This store's payments are still pending identity verification.";
            return ['ok' => false, 'reason' => 'kyc_required', 'message' => $message];
        }

        if ($status < 200 || $status >= 300) {
            $message = is_string($body['error'] ?? null) ? $body['error'] : "Payment link creation failed ({$status}).";
            return ['ok' => false, 'reason' => 'unknown', 'message' => $message];
        }

        $link = $body['link'] ?? null;
        if (!is_array($link)) {
            return ['ok' => false, 'reason' => 'unknown', 'message' => 'Payment link creation returned an unexpected response.'];
        }

        return ['ok' => true, 'link' => $link];
    }

    /**
     * Public, unauthenticated read used by the checkout payment page's poll.
     *
     * @return array<string, mixed>|null null when the token is unknown or the request failed.
     */
    public function fetchStatus(string $token): ?array
    {
        $client = new GuzzleClient(['timeout' => 10]);

        try {
            $response = $client->get("{$this->mudbaseUrl}/api/payment-links/{$token}", ['http_errors' => false]);
        } catch (GuzzleException) {
            return null;
        }

        if ($response->getStatusCode() >= 400) {
            return null;
        }

        $body = json_decode((string) $response->getBody(), true);
        $link = is_array($body) ? ($body['link'] ?? null) : null;
        return is_array($link) ? $link : null;
    }
}
