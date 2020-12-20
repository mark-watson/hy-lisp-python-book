# Running Hy in Jupyter Notebooks

This chapter is optional material for running many of the examples in this book in Jupyter notebooks. If you don't mind taking a few minutes to install Jupyter Notebooks and the [Hy kernal by Calysto](https://github.com/Calysto/calysto_hy) using the notebooks for this chapter is a fast overview for the material in this book. Alternatively, you might want to read the rest of the book first to better understand the examples and then revisit this chapter later.

## Install Requirements

Assuming that you have a recent Python 3.x and Hy installed, you will additionally need:

```bash
pip install jupyter
pip install git+https://github.com/ekaschalk/jedhy.git
pip install git+https://github.com/Calysto/calysto_hy.git
python -m calysto_hy install
```

I stored the Jupyter Notebook files in a separate github repository that you will want to clone:

```bash
git clone https://github.com/mark-watson/hylang-jupyter-notesbooks.git
cd hylang-jupyter-notesbooks
```

From insdie the directory hylang-jupyter-notesbooks, you can now run Jupyter with the newly installed Calysto Hy kernel using:

```bash
jupyter console --kernel calysto_hy
```

The **File** menu can then be used to open the sample Jupiter Notebooks from this git repository.


