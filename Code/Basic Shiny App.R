library(shiny)
library(ggplot2)
library(DT)

# Load the data from the CSV file (make sure to adjust the file path)
data <- read.csv("cleaned_data.csv")

# Define the UI
ui <- fluidPage(
  tags$head(
    tags$script(HTML('
      $(document).ready(function() {
        // Initialize image visibility
        $("#abdomen_image").hide();
        $("#chest_image").hide();
        $("#wrist_image").hide();
        $("#scatter_plot").hide(); // Hide the scatter plot initially

        // Show/hide images and scatter plot based on button clicks
        $("#show_abdomen").click(function() {
          $("#abdomen_image").show();
          $("#chest_image").hide();
          $("#wrist_image").hide();
          $("#scatter_plot").hide(); // Hide the scatter plot when showing images
          Shiny.setInputValue("reset_scatter_brush", true, {priority: "event"});
        });

        $("#show_chest").click(function() {
          $("#abdomen_image").hide();
          $("#chest_image").show();
          $("#wrist_image").hide();
          $("#scatter_plot").hide(); // Hide the scatter plot when showing images
          Shiny.setInputValue("reset_scatter_brush", true, {priority: "event"});
        });

        $("#show_wrist").click(function() {
          $("#abdomen_image").hide();
          $("#chest_image").hide();
          $("#wrist_image").show();
          $("#scatter_plot").hide(); // Hide the scatter plot when showing images
          Shiny.setInputValue("reset_scatter_brush", true, {priority: "event"});
        });

        $("#calculate").click(function() {
          $("#abdomen_image").hide();
          $("#chest_image").hide();
          $("#wrist_image").hide();
          $("#scatter_plot").show(); // Show the scatter plot when Calculate is clicked
        });
      });
    '))
  ),
  titlePanel("Bodyfat Prediction App"),
  fluidRow(
    column(3,
           numericInput("abdomen", "ABDOMEN (inches):", value = 35.43),
           numericInput("chest", "CHEST (inches):", value = 42),
           numericInput("wrist", "WRIST (inches):", value = 8.5),
           numericInput("adiposity", "ADIPOSITY:", value = 30),
           actionButton("calculate", "Calculate"),
           actionButton("show_abdomen", "Show Abdomen Image"),
           actionButton("show_chest", "Show Chest Image"),
           actionButton("show_wrist", "Show Wrist Image")
    ),
    column(9,
           mainPanel(
             h4("Predicted Bodyfat:"),
             verbatimTextOutput("predicted_bodyfat"),
             h4("Predicted Density:"),
             verbatimTextOutput("predicted_density"),
             plotOutput("regression_plot", brush = brushOpts(id = "regression_brush")),
             plotOutput("scatter_plot", brush = brushOpts(id = "scatter_brush")),  # Add the scatter plot here
             conditionalPanel(
               condition = "input.show_abdomen",
               imageOutput("abdomen_image")
             ),
             conditionalPanel(
               condition = "input.show_chest",
               imageOutput("chest_image")
             ),
             conditionalPanel(
               condition = "input.show_wrist",
               imageOutput("wrist_image")
             )
           )
    )
  ),
  fluidRow(
    column(12,
           dataTableOutput("user_info_table")
    )
  )
)

# Define the server logic
server <- function(input, output, session) {
  # Linear regression coefficients for the model to predict density
  coefficients_density <- c(-0.00527214, 0.00045475, 0.01166926)
  intercept_density <- 1.1193190404360203
  
  # Linear regression coefficients for the model to predict bodyfat
  coefficients_bodyfat <- c(2.08827449e-01, -3.23329199e+02, 1.80207842e-01)
  intercept_bodyfat <- 348.0722797501468
  
  # Create a reactiveValues object to store brushed points
  brushed_points_data <- reactiveValues(
    scatter_data = NULL,
    regression_data = NULL
  )
  
  # Error handling for invalid input
  observe({
    if (input$calculate > 0) {
      validate(
        need(is.numeric(input$abdomen) && is.numeric(input$chest) && is.numeric(input$wrist) && is.numeric(input$adiposity), 
             "Please enter valid numbers.")
      )
    }
  })
  
  # Perform density prediction based on user inputs
  density_prediction_result <- eventReactive(input$calculate, {
    abdomen <- as.numeric(input$abdomen)
    chest <- as.numeric(input$chest)
    wrist <- as.numeric(input$wrist)
    adiposity <- as.numeric(input$adiposity)
    
    if (is.numeric(abdomen) && is.numeric(chest) && is.numeric(wrist) && is.numeric(adiposity)) {
      # Calculate the predicted density
      predicted_density <- intercept_density +
        coefficients_density[1] * abdomen +
        coefficients_density[2] * chest +
        coefficients_density[3] * wrist
      
      return(predicted_density)
    } else {
      return("Invalid input. Please enter valid numbers.")
    }
  })
  
  # Perform bodyfat prediction based on the predicted density
  bodyfat_prediction_result <- eventReactive(input$calculate, {
    predicted_density <- density_prediction_result()
    
    if (is.numeric(predicted_density)) {
      abdomen <- as.numeric(input$abdomen) # Retrieve abdomen value from input
      
      # Calculate the predicted bodyfat using the specified coefficients
      predicted_bodyfat <- coefficients_bodyfat[1] * abdomen +
        coefficients_bodyfat[2] * predicted_density +
        coefficients_bodyfat[3] * input$adiposity +
        intercept_bodyfat
      
      return(list(predicted_density = predicted_density, predicted_bodyfat = predicted_bodyfat))
    } else {
      return("Invalid input. Please enter valid numbers.")
    }
  })
  
  # Display the predicted bodyfat and predicted density or error messages
  output$predicted_bodyfat <- renderText({
    result <- bodyfat_prediction_result()
    if (is.numeric(result$predicted_bodyfat)) {
      paste("Predicted Bodyfat:", result$predicted_bodyfat)
    } else {
      result$predicted_bodyfat
    }
  })
  
  output$predicted_density <- renderText({
    result <- bodyfat_prediction_result()
    if (is.numeric(result$predicted_density)) {
      paste("Predicted Density:", result$predicted_density)
    } else {
      result$predicted_density
    }
  })
  
  # Create a scatter plot with predicted bodyfat for user input and all data points
  output$regression_plot <- renderPlot({
    abdomen <- as.numeric(input$abdomen)
    adiposity <- as.numeric(input$adiposity)
    
    if (is.numeric(abdomen) && is.numeric(adiposity)) {
      # Calculate predicted bodyfat for all data points
      predicted_bodyfat_data <- coefficients_bodyfat[1] * data$ABDOMEN +
        coefficients_bodyfat[2] * data$DENSITY +
        coefficients_bodyfat[3] * data$ADIPOSITY +
        intercept_bodyfat
      
      # Create data frame for data points
      data_data <- data.frame(
        DENSITY = data$DENSITY,
        PREDICTED_BODYFAT = predicted_bodyfat_data,
        SOURCE = "Data"
      )
      
      # Combine user input and data points
      user_input <- data.frame(
        DENSITY = density_prediction_result(),
        PREDICTED_BODYFAT = bodyfat_prediction_result()$predicted_bodyfat,
        SOURCE = "User Input"
      )
      
      p <- ggplot() +
        geom_point(data = data_data, aes(x = DENSITY, y = PREDICTED_BODYFAT, color = SOURCE), size = 3) +
        geom_point(data = user_input, aes(x = DENSITY, y = PREDICTED_BODYFAT, color = SOURCE), size = 3) +
        labs(x = "Density", y = "Predicted Bodyfat", title = "Bodyfat Prediction") +
        scale_color_manual(values = c("User Input" = "red", "Data" = "blue"))
      
      brushed_points_data$regression_data <- brushedPoints(data_data, input$regression_brush, xvar = "DENSITY", yvar = "PREDICTED_BODYFAT")
      
      p
    }
  })
  
  # Create a scatter plot for Density vs Abdomen
  output$scatter_plot <- renderPlot({
    abdomen <- as.numeric(input$abdomen)
    
    if (is.numeric(abdomen)) {
      # Create a scatter plot
      p <- ggplot(data, aes(x = ABDOMEN, y = DENSITY)) +
        geom_point(size = 3) +
        labs(x = "ABDOMEN", y = "Density", title = "Density vs Abdomen Scatter Plot")
      
      brushed_points_data$scatter_data <- brushedPoints(data, input$scatter_brush, xvar = "ABDOMEN", yvar = "DENSITY")
      
      p
    }
  })
  
  # Create a reactive dataset that depends on brushed points
  reactive_data <- reactive({
    brushed_data_regression <- brushed_points_data$regression_data
    brushed_data_scatter <- brushed_points_data$scatter_data
    
    if (!is.null(brushed_data_regression) && !is.null(brushed_data_scatter)) {
      # Combine brushed data from both scatter and regression plots
      brushed_data <- rbind(brushed_data_regression, brushed_data_scatter)
      selected_densities <- brushed_data$DENSITY
      filtered_data <- data[data$DENSITY %in% selected_densities, ]
      return(filtered_data)
    } else {
      return(data)
    }
  })
  
  # Render the user information table
  output$user_info_table <- renderDT({
    datatable(reactive_data())
  })
  
  # Dynamically set image sources based on input buttons
  output$abdomen_image <- renderImage({
    if (input$show_abdomen) {
      list(src = "Abs.png", width = "500px", height = "auto")
    } else {
      list(src = NULL, width = "500px", height = "auto")
    }
  }, deleteFile = FALSE)
  
  output$chest_image <- renderImage({
    if (input$show_chest) {
      list(src = "Chest.png", width = "500px", height = "auto")
    } else {
      list(src = NULL, width = "500px", height = "auto")
    }
  }, deleteFile = FALSE)
  
  output$wrist_image <- renderImage({
    if (input$show_wrist) {
      list(src = "Wrist.png", width = "500px", height = "auto")
    } else {
      list(src = NULL, width = "500px", height = "auto")
    }
  }, deleteFile = FALSE)
}

# Run the Shiny app
shinyApp(ui = ui, server = server)
