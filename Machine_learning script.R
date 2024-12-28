#-------------------------------------------------------------------------------
#             Data Loading
#-------------------------------------------------------------------------------

# Setting up the working directory
getwd()
setwd("C:/Users/TMB CO/Desktop/Statistical Modelling/MACHINE_LEARNING")

# reading the csv file
data= read.csv('PAU Data Science Social_Network_Ads and purchase Data.csv')

# Check the number of rows and columns
dim(data)
# Check data structure and missing values
str(head(data, 2))
sum(is.na(data))

#-------------------------------------------------------------------------------
#             Data Preprocessing
#-------------------------------------------------------------------------------

# Load necessary libraries
library(dplyr)
library(caret)        # For model training and evaluation
library(rpart)        # For Decision Tree
library(rpart.plot)   # For visualizing the tree
library(ggplot2)      # For confusion matrix visualization
library(pROC)         # For ROC and AUC
library(openxlsx)     # For working with Excel files

# Remove User.ID column if it exists
data$User.ID <- NULL

# Map "Male" to "1" and "Female" to "0" in the Gender column
data$Gender <- recode(data$Gender, "Male" = "1", "Female" = "0")

# Ensure 'Gender' and 'Purchased' are factors with the same levels as in the data
data$Gender <- factor(data$Gender, levels = c("0", "1"))
data$Purchased <- factor(data$Purchased, levels = c("0", "1"))

# Scale Age and EstimatedSalary to have mean 0 and variance 1
## data$Age <- scale(data$Age)
## data$EstimatedSalary <- scale(data$EstimatedSalary)

# Check the structure of the data after preprocessing (first 2 rows)
str(head(data, 2))

# Check the levels of the factor variables to ensure correct encoding
levels(data$Gender)
levels(data$Purchased)

#-------------------------------------------------------------------------------
#       Split Data Into Training and Testing Sets:
#-------------------------------------------------------------------------------

# Split into training and testing sets (80% training, 20% testing)
set.seed(123)  # Set seed for reproducibility
train_index <- createDataPartition(data$Purchased, p = 0.8, list = FALSE)  # 80% for training
train_data <- data[train_index, ]  # Training data
test_data <- data[-train_index, ]  # Testing data


#-------------------------------------------------------------------------------
#   Summary statistics table for training and testing set:
#-------------------------------------------------------------------------------

# Generate summary statistics for training and testing datasets
summary_train <- summary(train_data)
print(summary_train)  # Print summary of the training data

summary_test <- summary(test_data)
print(summary_test)  # Print summary of the testing data



#-------------------------------------------------------------------------------
#     Train a Logistic Regression Model:
#-------------------------------------------------------------------------------

# Train the model
log_reg_model <- glm(Purchased ~ Gender + Age + EstimatedSalary, 
                     data = train_data, 
                     family = binomial)
summary(log_reg_model)


#-------------------------------------------------------------------------------
#     Make Predictions on Test Data:
#-------------------------------------------------------------------------------

# Predict probabilities on the test set
test_probs <- predict(log_reg_model, newdata = test_data, type = "response")

# Convert probabilities to class predictions using a 0.5 threshold
test_predictions <- ifelse(test_probs > 0.5, "1", "0")

# Convert the predictions to a factor with levels matching the reference (test_data$Purchased)
test_predictions <- factor(test_predictions, levels = c("0", "1"))

# Ensure the reference (true labels) is a factor with the same levels
test_data$Purchased <- factor(test_data$Purchased, levels = c("0", "1"))



#-------------------------------------------------------------------------------
#     Make Predictions on New Data:
#-------------------------------------------------------------------------------


# The function to predict purchase
predict_purchase <- function(EstimatedSalary, Age, Gender) {
  # Create a data frame with the input variables
  input_data <- data.frame(
    EstimatedSalary = EstimatedSalary,
    Age = Age,
    Gender = factor(Gender, levels = c("0", "1"))  # Ensure Gender is a factor with the correct levels
  )
  
  # Scale the input variables (same scaling as done during model training)
  input_data$Age <- scale(input_data$Age, center = attr(data$Age, "scaled:center"), 
                          scale = attr(data$Age, "scaled:scale"))
  input_data$EstimatedSalary <- scale(input_data$EstimatedSalary, 
                                      center = attr(data$EstimatedSalary, "scaled:center"), 
                                      scale = attr(data$EstimatedSalary, "scaled:scale"))
  
  # Predict the probability of purchase
  prob <- predict(log_reg_model, newdata = input_data, type = "response")
  
  # Convert the probability to a class prediction using a 0.5 threshold
  prediction <- ifelse(prob > 0.5, "1", "0")
  
  # Return the prediction as a factor
  return(factor(prediction, levels = c("0", "1")))
}

# Example usage of the function
## predicted_purchase <- predict_purchase(EstimatedSalary = 20000, Age = 30, Gender = "1")
## print(predicted_purchase)


#-------------------------------------------------------------------------------
#     Save Model Evaluation parameters to excel:
#-------------------------------------------------------------------------------

# Compute confusion matrix
conf_matrix <- confusionMatrix(test_predictions, test_data$Purchased)

# Extract only important confusion matrix metrics
cm_summary <- data.frame(
  Metric = c("Accuracy", "95% CI", "Kappa", "Sensitivity", "Specificity",
             "Pos Pred Value", "Neg Pred Value", "Balanced Accuracy"),
  Value = c(
    conf_matrix$overall["Accuracy"],
    paste("(", conf_matrix$overall["AccuracyLower"], ", ", conf_matrix$overall["AccuracyUpper"], ")", sep = ""),
    conf_matrix$overall["Kappa"],
    conf_matrix$byClass["Sensitivity"],
    conf_matrix$byClass["Specificity"],
    conf_matrix$byClass["Pos Pred Value"],
    conf_matrix$byClass["Neg Pred Value"],
    conf_matrix$byClass["Balanced Accuracy"]
  )
)

# Transpose the data frame to make it horizontal (row as metrics, column as values)
cm_summary_transposed <- as.data.frame(t(cm_summary$Value))
colnames(cm_summary_transposed) <- cm_summary$Metric

# Convert to data frame
cm_summary_df <- data.frame(cm_summary_transposed)

# Function to save or append confusion matrix to Excel file
save_to_excel <- function(data, file, sheet = "ConfusionMatrixResults") {
  if (!file.exists(file)) {
    # If the file does not exist, create a new workbook and add data
    wb <- createWorkbook()
    addWorksheet(wb, sheet)
    writeData(wb, sheet, data)
    saveWorkbook(wb, file, overwrite = TRUE)
  } else {
    # If the file exists, load the workbook and append data
    wb <- loadWorkbook(file)
    if (!sheet %in% names(wb)) {
      addWorksheet(wb, sheet)
    }
    existing_data <- read.xlsx(file, sheet = sheet)
    if (ncol(existing_data) == ncol(data)) {
      # Append only if the number of columns match
      combined_data <- rbind(existing_data, data)
      writeData(wb, sheet, combined_data)
      saveWorkbook(wb, file, overwrite = TRUE)
    } else {
      warning("Column count mismatch. Cannot append data.")
    }
  }
}

# Specify the file name
excel_file <- "ConfusionMatrixResults.xlsx"

# Save the confusion matrix summary with only important metrics
save_to_excel(cm_summary_df, excel_file)


#-------------------------------------------------------------------------------
#     Save the model for deployment:
#-------------------------------------------------------------------------------

# Save the model to an RDS file
saveRDS(log_reg_model, "log_reg_model.rds")
cat("Logistic regression model saved as 'log_reg_model.rds'\n")

summary(log_reg_model)

