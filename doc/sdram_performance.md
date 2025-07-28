# SDRAM performance

## Introduction

The performance is measured using the regression test. It count the total ns need to complete the regression test.

Regression parameter:
- clock frequency: 133
- cocotb RANDOM_SEED = 0

Test factory:

```python
random_factory = TestFactory(test_random_read_write)
random_factory.add_option("num_op", [0x4000])
random_factory.add_option("num_seq", [1000])
random_factory.generate_tests()

sequential_factory = TestFactory(test_sequential_read_write)
sequential_factory.add_option("start_addr", [0])
sequential_factory.add_option("end_addr",   [0x4000])
sequential_factory.generate_tests()
```

## Test Result

### Sequential Access

| Design Variants    | Version | Test Time     |
| ------------------ | ------- | ------------- |
| sdram_simple_ap.sv | v0      | 1226524.00 ns |
| sdram_simple_mp.sv | v0      | 833836.00 ns  |

### Random Access

| Design Variants    | Version | Test Time     |
| ------------------ | ------- | ------------- |
| sdram_simple_ap.sv | v0      | 1226884.00 ns |
| sdram_simple_mp.sv | v0      | 1357356.00 ns |