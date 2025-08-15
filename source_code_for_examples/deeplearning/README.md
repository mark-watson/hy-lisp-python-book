# Hy deep learning examples

2025/08/15: updated code to work with tensorflow-2.20.0 and latest numpy.

```
$ uv add hy
$ uv run hy lstm.hy
```

Note: having **hy** in requirements.txt is not sufficient!! **uv add hy** ensures that the **hy** executable is installed in the local .venv environment.

```
$ uv add pandas
$ uv run hy wisconsin.hy
* predictions (calculated, expected):
1/1 ━━━━━━━━━━━━━━━━━━━━ 0s 15ms/step
[(np.float32(0.9977402), np.int64(1)), (np.float32(0.9999937), np.int64(1)), (np.float32(0.86606896), np.int64(1)), (np.float32(0.9598365), np.int64(1)), (np.float32(0.025319753), np.int64(0)), (np.float32(0.13894384), np.int64(0)), (np.float32(0.999159), np.int64(1)), (np.float32(0.16339315), np.int64(0)), (np.float32(0.030820148), np.int64(0)), (np.float32(0.99996793), np.int64(1))]
```