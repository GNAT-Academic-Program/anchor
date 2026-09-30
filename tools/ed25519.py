"""Ed25519 signatures in pure Python (standard library only).

This is the reference implementation from RFC 8032, section 6, lightly
formatted. It is slow and not constant-time. That is fine here: it only
runs on the laptop, on test keys, to sign small manifests.

Never use this file to handle a real secret key.
"""

import hashlib

p = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
d = -121665 * pow(121666, p - 2, p) % p


def _sha512(data):
    return hashlib.sha512(data).digest()


def _inv(x):
    return pow(x, p - 2, p)


def _sha512_mod_l(data):
    return int.from_bytes(_sha512(data), "little") % L


# Points are (X, Y, Z, T) in extended coordinates: x = X/Z, y = Y/Z, x*y = T/Z.

def _add(P, Q):
    A = (P[1] - P[0]) * (Q[1] - Q[0]) % p
    B = (P[1] + P[0]) * (Q[1] + Q[0]) % p
    C = 2 * P[3] * Q[3] * d % p
    D = 2 * P[2] * Q[2] % p
    E, F, G, H = B - A, D - C, D + C, B + A
    return (E * F % p, G * H % p, F * G % p, E * H % p)


def _mul(s, P):
    Q = (0, 1, 1, 0)  # neutral element
    while s > 0:
        if s & 1:
            Q = _add(Q, P)
        P = _add(P, P)
        s >>= 1
    return Q


def _equal(P, Q):
    if (P[0] * Q[2] - Q[0] * P[2]) % p != 0:
        return False
    if (P[1] * Q[2] - Q[1] * P[2]) % p != 0:
        return False
    return True


_SQRT_M1 = pow(2, (p - 1) // 4, p)


def _recover_x(y, sign):
    if y >= p:
        return None
    x2 = (y * y - 1) * _inv(d * y * y + 1)
    if x2 % p == 0:
        return None if sign else 0
    x = pow(x2, (p + 3) // 8, p)
    if (x * x - x2) % p != 0:
        x = x * _SQRT_M1 % p
    if (x * x - x2) % p != 0:
        return None
    if (x & 1) != sign:
        x = p - x
    return x


_GY = 4 * _inv(5) % p
_GX = _recover_x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % p)


def _compress(P):
    zinv = _inv(P[2])
    x = P[0] * zinv % p
    y = P[1] * zinv % p
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def _decompress(s):
    if len(s) != 32:
        return None
    y = int.from_bytes(s, "little")
    sign = y >> 255
    y &= (1 << 255) - 1
    x = _recover_x(y, sign)
    if x is None:
        return None
    return (x, y, 1, x * y % p)


def _expand(secret):
    if len(secret) != 32:
        raise ValueError("an Ed25519 secret key is 32 bytes")
    h = _sha512(secret)
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return a, h[32:]


def public_key(secret):
    """32-byte public key for a 32-byte secret key."""
    a, _ = _expand(secret)
    return _compress(_mul(a, _G))


def sign(secret, message):
    """64-byte signature of message."""
    a, prefix = _expand(secret)
    A = _compress(_mul(a, _G))
    r = _sha512_mod_l(prefix + message)
    Rs = _compress(_mul(r, _G))
    h = _sha512_mod_l(Rs + A + message)
    s = (r + h * a) % L
    return Rs + int.to_bytes(s, 32, "little")


def verify(public, message, signature):
    """True when signature is valid for message under public."""
    if len(public) != 32 or len(signature) != 64:
        return False
    A = _decompress(public)
    if A is None:
        return False
    Rs = signature[:32]
    R = _decompress(Rs)
    if R is None:
        return False
    s = int.from_bytes(signature[32:], "little")
    if s >= L:
        return False
    h = _sha512_mod_l(Rs + public + message)
    return _equal(_mul(s, _G), _add(R, _mul(h, A)))
