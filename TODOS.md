* [ ] `move` should wait 200 ticks
* [ ] `move` should render
* [ ] `move` should wrap around
* [ ] have a manual way of unlocking unlocks
* [ ] visually display unlocks and what they do
* [ ] add docstrings, same as the wiki / real game
* [ ] add `plant(Entities.bush)` command
* [ ] add the "plant" unlock
* [ ] make `sleep` and `render` optional, and prove that functions like `wait_ticks` with a `none` sleep and render are equivalent to a simple increment of ticks
* [ ] as long as `unlock_expand_1` is not bought, `move` is the same as a noop (prove it)
* [ ] prove that as long as `unlock_expand_1` is not bought, `move .east` and `move .west` are noops
* [ ] add `can_harvest()` — returns whether the crop has fully grown, and itself waits 1 tick. Motivation: after `unlock_speed_1`, a tight `loop { harvest }` is too fast for the crop to regrow; harvesting an ungrown crop resets its growth timer and yields nothing. With `can_harvest()` you can poll in a loop and the crop will eventually be ready
