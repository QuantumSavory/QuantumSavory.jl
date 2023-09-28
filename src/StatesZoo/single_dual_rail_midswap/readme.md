The above code was translated from the code in the matlab files in the adjoining folder. The process for converting to julia involved:
- Removing the broadcasting operator `.`, because the calculation is being performed on scalars.
- Some spots needed the addition of brackets to clarify the ambiguity caused by the priority of operations.
- Some spots needed `\` merging with previous line to avoid to ambiguity about end of expression.

Then the output of the functions were linked to their corresponding symboic object which can be expressed as a density matrix in QuantumOptics representation.