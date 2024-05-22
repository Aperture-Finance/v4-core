// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @notice Thrown when the tick passed to #getSqrtPriceAtTick is not between MIN_TICK and MAX_TICK
    error InvalidTick();
    /// @notice Thrown when the price passed to #getTickAtSqrtPrice does not correspond to a price between MIN_TICK and MAX_TICK
    error InvalidSqrtPrice();

    /// @dev The minimum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtPriceAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = 887272;

    /// @dev The minimum tick spacing value drawn from the range of type int16 that is greater than 0, i.e. min from the range [1, 32767]
    int24 internal constant MIN_TICK_SPACING = 1;
    /// @dev The maximum tick spacing value drawn from the range of type int16, i.e. max from the range [1, 32767]
    int24 internal constant MAX_TICK_SPACING = type(int16).max;

    /// @dev The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    /// @dev A threshold used for optimized bounds check, equals `MAX_SQRT_PRICE - MIN_SQRT_PRICE - 1`
    uint160 internal constant MAX_SQRT_PRICE_MINUS_MIN_SQRT_PRICE_MINUS_ONE =
        1461446703485210103287273052203988822378723970342 - 4295128739 - 1;

    /// @notice Given a tickSpacing, compute the maximum usable tick
    function maxUsableTick(int24 tickSpacing) internal pure returns (int24) {
        unchecked {
            return (MAX_TICK / tickSpacing) * tickSpacing;
        }
    }

    /// @notice Given a tickSpacing, compute the minimum usable tick
    function minUsableTick(int24 tickSpacing) internal pure returns (int24) {
        unchecked {
            return (MIN_TICK / tickSpacing) * tickSpacing;
        }
    }

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the price of the two assets (currency1/currency0)
    /// at the given tick
    function getSqrtPriceAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick;
            assembly {
                // mask = 0 if tick >= 0 else -1 (all 1s)
                let mask := sar(255, tick)
                // if tick >= 0, |tick| = tick = 0 ^ tick
                // if tick < 0, |tick| = ~~|tick| = ~(-|tick| - 1) = ~(tick - 1) = (-1) ^ (tick - 1)
                // either way, |tick| = mask ^ (tick + mask)
                absTick := xor(mask, add(mask, tick))
            }
            // Equivalent: if (absTick > MAX_TICK) revert InvalidTick();
            /// @solidity memory-safe-assembly
            assembly {
                if gt(absTick, MAX_TICK) {
                    // store 4-byte selector of "InvalidTick()" at memory [0x1c, 0x20)
                    mstore(0, 0xce8ef7fc)
                    revert(0x1c, 0x04)
                }
            }

            // Equivalent to:
            //     price = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
            //     or price = int(2**128 / sqrt(1.0001)) if (absTick & 0x1) else 1 << 128
            uint256 price;
            assembly {
                price := xor(shl(128, 1), mul(xor(shl(128, 1), 0xfffcb933bd6fad37aa2d162d1a594001), and(absTick, 0x1)))
            }
            if (absTick & 0x2 != 0) price = (price * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) price = (price * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) price = (price * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) price = (price * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) price = (price * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) price = (price * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) price = (price * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) price = (price * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) price = (price * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) price = (price * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) price = (price * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) price = (price * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) price = (price * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) price = (price * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) price = (price * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) price = (price * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) price = (price * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) price = (price * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) price = (price * 0x48a170391f7dc42444e8fa2) >> 128;

            assembly {
                // if (tick > 0) price = type(uint256).max / price;
                if sgt(tick, 0) { price := div(not(0), price) }

                // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
                // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
                // we round up in the division so getTickAtSqrtPrice of the output price is always consistent
                // `sub(shl(32, 1), 1)` is `type(uint32).max`
                // `price + type(uint32).max` will not overflow because `price` fits in 192 bits
                sqrtPriceX96 := shr(32, add(price, sub(shl(32, 1), 1)))
            }
        }
    }

    /// @notice Calculates the greatest tick value such that getPriceAtTick(tick) <= price
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_PRICE, as MIN_SQRT_PRICE is the lowest value getPriceAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt price for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the price is less than or equal to the input price
    function getTickAtSqrtPrice(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        unchecked {
            // Equivalent: if (sqrtPriceX96 < MIN_SQRT_PRICE || sqrtPriceX96 >= MAX_SQRT_PRICE) revert InvalidSqrtPrice();
            // second inequality must be >= because the price can never reach the price at the max tick
            /// @solidity memory-safe-assembly
            assembly {
                // if sqrtPriceX96 < MIN_SQRT_PRICE, the `sub` underflows and `gt` is true
                // if sqrtPriceX96 >= MAX_SQRT_PRICE, sqrtPriceX96 - MIN_SQRT_PRICE > MAX_SQRT_PRICE - MIN_SQRT_PRICE - 1
                if gt(sub(sqrtPriceX96, MIN_SQRT_PRICE), MAX_SQRT_PRICE_MINUS_MIN_SQRT_PRICE_MINUS_ONE) {
                    // store 4-byte selector of "InvalidSqrtPrice()" at memory [0x1c, 0x20)
                    mstore(0, 0x31efafe8)
                    revert(0x1c, 0x04)
                }
            }

            // Find the most significant bit of `sqrtPriceX96`, 160 > msb >= 32.
            uint256 msb;
            assembly {
                let x := sqrtPriceX96
                msb := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
                msb := or(msb, shl(6, lt(0xffffffffffffffff, shr(msb, x))))
                msb := or(msb, shl(5, lt(0xffffffff, shr(msb, x))))
                msb := or(msb, shl(4, lt(0xffff, shr(msb, x))))
                msb := or(msb, shl(3, lt(0xff, shr(msb, x))))
                msb :=
                    or(
                        msb,
                        byte(
                            and(0x1f, shr(shr(msb, x), 0x8421084210842108cc6318c6db6d54be)),
                            0x0706060506020504060203020504030106050205030304010505030400000000
                        )
                    )
            }

            // 2**(msb - 95) > sqrtPrice >= 2**(msb - 96)
            // the integer part of log_2(sqrtPrice) * 2**64 = (msb - 96) << 64, 8.64 number
            int256 log_2 = (int256(msb) - 96) << 64;
            assembly {
                // Get the first 128 significant figures of `sqrtPriceX96`.
                // r = sqrtPriceX96 / 2**(msb - 127), where 2**128 > r >= 2**127
                // sqrtPrice = 2**(msb - 96) * r / 2**127, in floating point math
                // Shift left first because 160 > msb >= 32. If we shift right first, we'll lose precision.
                let r := shr(sub(msb, 31), shl(96, sqrtPriceX96))

                // Approximate `log_2` to 14 binary digits after decimal
                // Check whether r >= sqrt(2) * 2**127 for 2**128 > r >= 2**127
                // 2**256 > square >= 2**254
                let square := mul(r, r)
                // f := square >= 2**255
                let f := slt(square, 0)
                // r := square >> 128 if square >= 2**255 else square >> 127
                r := shr(127, shr(f, square))
                log_2 := or(shl(63, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(62, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(61, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(60, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(59, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(58, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(57, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(56, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(55, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(54, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(53, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(52, f), log_2)

                square := mul(r, r)
                f := slt(square, 0)
                r := shr(127, shr(f, square))
                log_2 := or(shl(51, f), log_2)

                log_2 := or(shl(50, slt(mul(r, r), 0)), log_2)
            }

            // sqrtPrice = sqrt(1.0001^tick)
            // tick = log_{sqrt(1.0001)}(sqrtPrice) = log_2(sqrtPrice) / log_2(sqrt(1.0001))
            // 2**64 / log_2(sqrt(1.0001)) = 255738958999603826347141
            int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

            int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
            int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

            tick = tickLow == tickHi ? tickLow : getSqrtPriceAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
        }
    }
}
