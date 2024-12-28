library(plumber)

# Load the logistic regression model
log_reg_model <- readr::read_rds("log_reg_model.rds")

#* @apiTitle Purchase Prediction API

#* @apiDescription This API predicts whether a purchase will occur based on the individual's estimated salary, age, and gender.

#* @param EstimatedSalary The estimated salary of an individual.
#* @param Age The age of the individual.
#* @param Gender The gender of the individual, must be either 'Male' or 'Female'.

#* @get /predict-purchase
function(EstimatedSalary, Age, Gender) {
  
  # Prepare the data frame for prediction
  to_predict <- data.frame(
    EstimatedSalary = as.numeric(EstimatedSalary),
    Age = as.numeric(Age),
    Gender = as.factor(Gender)
  )
  
  # Make predictions using the logistic regression model
  prediction_probs <- predict(log_reg_model, to_predict, type = "response")
  
  # Convert the probabilities to binary class predictions (threshold at 0.5)
  prediction <- ifelse(prediction_probs > 0.5, "1", "0")
  
  # Return the prediction as a response
  return(list(purchase_prediction = prediction))
}
