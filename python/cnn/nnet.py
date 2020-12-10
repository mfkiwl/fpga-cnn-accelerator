import numpy as np
from .loss import SoftmaxLoss, l2_regularization, delta_l2_regularization
from .utils import accuracy, softmax

class CNN:

    def __init__(self, layers, loss_func=SoftmaxLoss):
        self.layers = layers
        self.params = []
        for layer in self.layers:
            self.params.append(layer.params)
        self.loss_func = loss_func

    def forward(self, X):
        temp = X
        for layer in self.layers:
            temp = layer.forward(temp)
        return temp

    def predict(self, X):
        X = self.forward(X)
        return np.argmax(softmax(X), axis=1)
