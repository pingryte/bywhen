import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn bywhen_test_runner_is_wired_test() {
  "goals" |> should.equal("goals")
}
