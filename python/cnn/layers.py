import numpy as np
from .im2col import *


class Conv():

    def __init__(self, X_dim, n_filter, h_filter, w_filter, stride, padding):

        self.d_X, self.h_X, self.w_X = X_dim

        self.n_filter, self.h_filter, self.w_filter = n_filter, h_filter, w_filter
        self.stride, self.padding = stride, padding

        self.W = np.random.randint(-128, 127, size=(n_filter, self.d_X, h_filter, w_filter))

        # self.W = np.random.randn(
        #     n_filter, self.d_X, h_filter, w_filter) / np.sqrt(n_filter / 2.)

        self.b = np.zeros((self.n_filter, 1))
        self.params = [self.W, self.b]

        self.h_out = (self.h_X - h_filter + 2 * padding) / stride + 1
        self.w_out = (self.w_X - w_filter + 2 * padding) / stride + 1

        if not self.h_out.is_integer() or not self.w_out.is_integer():
            raise Exception("Invalid dimensions!")

        self.h_out, self.w_out = int(self.h_out), int(self.w_out)
        self.out_dim = (self.n_filter, self.h_out, self.w_out)

    def forward(self, X):

        self.n_X = X.shape[0]

        self.X_col = im2col_indices(
            X, self.h_filter, self.w_filter, stride=self.stride, padding=self.padding)
        W_row = self.W.reshape(self.n_filter, -1)

        out = W_row @ self.X_col + self.b
        out = out.reshape(self.n_filter, self.h_out, self.w_out, self.n_X)
        out = out.transpose(3, 0, 1, 2)

        return out


class Maxpool():

    def __init__(self, X_dim, size, stride):

        self.d_X, self.h_X, self.w_X = X_dim

        self.params = []

        self.size = size
        self.stride = stride

        self.h_out = (self.h_X - size) / stride + 1
        self.w_out = (self.w_X - size) / stride + 1

        if not self.h_out.is_integer() or not self.w_out.is_integer():
            raise Exception("Invalid dimensions!")

        self.h_out, self.w_out = int(self.h_out), int(self.w_out)
        self.out_dim = (self.d_X, self.h_out, self.w_out)

    def forward(self, X):
        self.n_X = X.shape[0]
        X_reshaped = X.reshape(
            X.shape[0] * X.shape[1], 1, X.shape[2], X.shape[3])

        self.X_col = im2col_indices(
            X_reshaped, self.size, self.size, padding=0, stride=self.stride)

        self.max_indexes = np.argmax(self.X_col, axis=0)
        out = self.X_col[self.max_indexes, range(self.max_indexes.size)]

        out = out.reshape(self.h_out, self.w_out, self.n_X,
                          self.d_X).transpose(2, 3, 0, 1)                        
        return out


class Flatten():

    def __init__(self):
        self.params = []

    def forward(self, X):
        self.X_shape = X.shape
        self.out_shape = (self.X_shape[0], -1)
        out = X.ravel().reshape(self.out_shape)
        self.out_shape = self.out_shape[1]
        return out


class FullyConnected():

    def __init__(self, in_size, out_size):
        self.W = np.random.randint(-128, 127, size=(in_size, out_size))
        self.b = np.zeros((1, out_size))
        self.params = [self.W, self.b]

    def forward(self, X):
        self.X = X
        out = self.X @ self.W + self.b
        return out


class Batchnorm():

    def __init__(self, X_dim, alpha, beta):
        self.k_X, self.d_X, self.h_X, self.w_X = X_dim
        # print(X_dim)
        self.alpha = np.full((1, int(np.prod(X_dim))), alpha)
        self.beta = np.full((1, int(np.prod(X_dim))), beta)
        self.params = [self.alpha, self.beta]

    def forward(self, X):
        self.n_X = X.shape[0]
        self.X_shape = X.shape

        print(self.X_shape)
        X_flat = X.ravel().reshape(self.n_X, -1)
        # self.X_norm = (self.X_flat - self.mu) / np.sqrt(self.var + 1e-8)
        out = self.alpha * X_flat + self.beta

        return out.reshape(self.X_shape)


class ReLU():
    def __init__(self):
        self.params = []

    def forward(self, X):
        self.X = X
        return np.maximum(0, X)


class sigmoid():
    def __init__(self):
        self.params = []

    def forward(self, X):
        out = 1.0 / (1.0 + np.exp(X))
        self.out = out
        return out


class tanh():
    def __init__(self):
        self.params = []

    def forward(self, X):
        out = np.tanh(X)
        self.out = out
        return out

