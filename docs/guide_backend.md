# Backend Guide

The end-user needs adapt this library for hookup into their own codebase. As an example they may see the [examples](../examples/) and [backend](../backend/) for working code of what this guide will go over.

When rendering text, the two products the user has to deal with: The text to draw and their "layering". Similar to UIs text should be drawn in layer batches, where each layer can represent a pass on some arbitrary set of distictions between the other layers.


