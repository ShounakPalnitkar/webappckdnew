import streamlit as st
import pandas as pd
import numpy as np
import joblib
import matplotlib.pyplot as plt
import seaborn as sns

# Load trained model and scaler
model = joblib.load("CKD_Model.pkl")
scaler = joblib.load("CKD_Scaler.pkl")

st.set_page_config(page_title="CKD Risk Predictor Chatbot", layout="centered")

# Custom CSS for chat interface
st.markdown("""
<style>
    .bot-message {
        padding: 12px;
        background: #f0f2f6;
        border-radius: 15px;
        margin: 5px 0;
        max-width: 80%;
        width: fit-content;
    }
    .user-message {
        padding: 12px;
        background: #007bff;
        color: white;
        border-radius: 15px;
        margin: 5px 0;
        max-width: 80%;
        width: fit-content;
        margin-left: auto;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'conversation' not in st.session_state:
    st.session_state.conversation = []
if 'current_question' not in st.session_state:
    st.session_state.current_question = 0
if 'user_responses' not in st.session_state:
    st.session_state.user_responses = {}

# Define questions with validation rules
questions = [
    {
        "key": "age",
        "text": "First, may I know your age?",
        "type": "number",
        "min": 1,
        "max": 120
    },
    {
        "key": "bp",
        "text": "What is your blood pressure reading (in mm Hg)? Normal range is typically between 90/60 and 120/80.",
        "type": "number",
        "min": 50,
        "max": 200
    },
    # Add all other questions with similar structure
    # ...
    {
        "key": "ane",
        "text": "Finally, have you been diagnosed with anemia? (Yes/No)",
        "type": "boolean"
    }
]

# Display conversation history
for msg in st.session_state.conversation:
    if msg['role'] == 'bot':
        st.markdown(f'<div class="bot-message">🤖 {msg["content"]}</div>', unsafe_allow_html=True)
    else:
        st.markdown(f'<div class="user-message">👤 {msg["content"]}</div>', unsafe_allow_html=True)

# Chat logic
if st.session_state.current_question < len(questions):
    current_q = questions[st.session_state.current_question]
    
    # Show current question if not already asked
    if not any(msg['key'] == current_q['key'] for msg in st.session_state.conversation):
        st.session_state.conversation.append({
            'role': 'bot',
            'content': current_q['text'],
            'key': current_q['key']
        })
        st.experimental_rerun()

    # Get user input
    user_input = st.chat_input("Type your answer here...")
    
    if user_input:
        try:
            # Validate input
            if current_q['type'] == 'number':
                value = float(user_input)
                if 'min' in current_q and value < current_q['min']:
                    raise ValueError(f"Value should be at least {current_q['min']}")
                if 'max' in current_q and value > current_q['max']:
                    raise ValueError(f"Value should be at most {current_q['max']}")
            elif current_q['type'] == 'boolean':
                value = 1 if user_input.lower() in ['yes', 'y', 'true'] else 0
            
            # Store valid response
            st.session_state.user_responses[current_q['key']] = value
            st.session_state.conversation.append({
                'role': 'user',
                'content': user_input,
                'key': current_q['key']
            })
            st.session_state.current_question += 1
            st.experimental_rerun()
            
        except ValueError as e:
            error_msg = f"Please enter a valid {current_q['type']}: {str(e)}"
            st.session_state.conversation.append({
                'role': 'bot',
                'content': f"❌ {error_msg}"
            })
            st.experimental_rerun()
else:
    # Show analysis and results
    st.session_state.conversation.append({
        'role': 'bot',
        'content': "🔍 Analyzing your responses..."
    })
    st.experimental_rerun()

    # Prepare data and make prediction
    input_df = pd.DataFrame([st.session_state.user_responses])
    scaled_data = scaler.transform(input_df)
    prediction = model.predict(scaled_data)[0]
    probability = model.predict_proba(scaled_data)[0][1]
    
    # Display results in chat format
    result_text = "High Risk of CKD ⚠️" if prediction == 1 else "Low Risk of CKD ✅"
    st.session_state.conversation.append({
        'role': 'bot',
        'content': f"""**Prediction Result**: {result_text}
        
        - Risk Probability: {probability*100:.1f}%
        - Key Factors: {', '.join(list(input_df.columns)[:3])}
        """
    })
    
    # Visualizations
    with st.expander("Detailed Analysis"):
        col1, col2 = st.columns(2)
        with col1:
            # Pie chart
            fig = plt.figure()
            plt.pie([probability, 1-probability], 
                    labels=['CKD Risk', 'No Risk'],
                    colors=['#ff6384', '#36a2eb'],
                    autopct='%1.1f%%')
            st.pyplot(fig)
        
        with col2:
            # Feature importance
            feature_importance = pd.Series(np.abs(scaled_data[0]), 
                                         index=input_df.columns).nlargest(5)
            st.bar_chart(feature_importance)
    
    # Add restart option
    st.session_state.conversation.append({
        'role': 'bot',
        'content': "Would you like to start over? (Yes/No)"
    })
    st.experimental_rerun()

# Handle restart
if st.session_state.current_question >= len(questions):
    user_input = st.chat_input("Type 'Yes' to restart...")
    if user_input and user_input.lower() in ['yes', 'y']:
        st.session_state.conversation = []
        st.session_state.current_question = 0
        st.session_state.user_responses = {}
        st.experimental_rerun()
