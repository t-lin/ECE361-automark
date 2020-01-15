# Example: Executable File
This example is for cases where the submission is a program (code), similar to programming courses. We simply pipe in input required, and redirect the output to file.
  * If the code is written in an interpreted language, can execute it directly. Otherwise, can use the `pre-test` script to compile it.
  * Use the `test` script to run the student's program. Can pipe in any inputs required.
  * Use the `check-output` script to parse the output and diff it against the reference solution.
    * This example will output a diff for students to help in their debugging (optional)

